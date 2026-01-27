# credo:disable-for-this-file Credo.Check.Refactor.CyclomaticComplexity

defmodule FrontWeb.ProjectController do
  use FrontWeb, :controller
  require Logger

  alias Front.Async
  alias Front.Audit
  alias Front.Decorators
  alias Front.MemoryCookie
  alias Front.Models

  alias Front.Models.{
    AgentType,
    Artifacthub,
    Deployments,
    Organization,
    Repohub,
    Secret,
    Job,
    Artifacthub,
    CommitJob,
    FetchingJob,
    User
  }

  alias FrontWeb.Plugs.{FetchPermissions, Header, PageAccess, PublicPageAccess, PutProjectAssigns}

  @org_pages ~w(index)a
  @public_proj_pages ~w(show workflows queues)a
  @edit_workflows ~w(edit_workflow blocked build_blocked commit_config check_commit_job fetch_yaml_artifacts)a
  @skip_for_page_authorization @org_pages ++ @public_proj_pages
  @yaml_artifact_directory ".workflow_editor/.semaphore"

  plug(FetchPermissions, [scope: "org"] when action in @org_pages)
  plug(PageAccess, [permissions: "organization.view"] when action in @org_pages)

  plug(PutProjectAssigns when action not in @org_pages)
  plug(FetchPermissions, [scope: "project"] when action not in @org_pages)
  plug(PublicPageAccess when action in @public_proj_pages)

  @skip_for_page_authorization @org_pages ++ @public_proj_pages
  plug(PageAccess, [permissions: "project.view"] when action not in @skip_for_page_authorization)
  plug(PageAccess, [permissions: "project.workflow.manage"] when action in @edit_workflows)

  plug(Header when action in [:index, :show, :new, :blocked, :edit_workflow])

  plug(:maybe_redirect_to_onboarding when action in [:show])

  def index(conn, _params) do
    Watchman.benchmark("project.list.duration", fn ->
      user_id = conn.assigns.user_id
      org_id = conn.assigns.organization_id
      page_number = 1

      fetch_organization = Async.run(fn -> Models.Organization.find(org_id) end)
      fetch_projects = Async.run(fn -> Models.Project.list(org_id, user_id, page_number) end)

      {:ok, organization} = Async.await(fetch_organization)

      if organization do
        {:ok, {projects, _page_count}} = Async.await(fetch_projects)

        conn
        |> render(
          "index.html",
          title: organization.name,
          categorized_projects: Front.Kondo.categorize_by_name(projects),
          organization: organization,
          layout: {FrontWeb.LayoutView, "organization.html"}
        )
      end
    end)
  end

  def show(conn, params) do
    metric_name =
      if user_page?(conn) do
        "project_controller.show-by-me.duration"
      else
        "project_controller.show.duration"
      end

    Watchman.benchmark(
      {metric_name, [conn.assigns.organization_id, conn.assigns.user_id]},
      fn ->
        Front.Tracing.track(conn.assigns.trace_id, "show", fn ->
          case conn.assigns.authorization do
            :member -> member(conn, params)
            :guest -> guest(conn, params)
          end
        end)
      end
    )
  end

  def workflows(conn, params) do
    Watchman.benchmark("refresh_workflows.duration", fn ->
      project = conn.assigns.project
      org_id = conn.assigns.organization_id
      user_id = conn.assigns.user_id

      params =
        struct!(Front.ProjectPage.Model.LoadParams,
          project_id: project.id,
          organization_id: org_id,
          user_id: user_id,
          page_token: params["page_token"] || "",
          direction: params["direction"] || "",
          list_mode: workflow_list_mode_setting(conn),
          user_page?: user_page?(conn),
          ref_types: ref_types(conn)
        )

      {:ok, model, source} =
        params |> Front.ProjectPage.Model.get(force_cold_boot: conn.params["force_cold_boot"])

      conn
      |> put_page_source_header(source)
      |> put_view(FrontWeb.DashboardView)
      |> put_layout(false)
      |> render(
        "partials/_workflows.html",
        workflows: model.workflows,
        pagination: model.pagination,
        pollman: pollman(conn, model),
        page: :project
      )
    end)
  end

  def edit_workflow(conn, params) do
    Watchman.benchmark("project.edit_workflow.duration", fn ->
      project = conn.assigns.project

      page_token = params |> Map.get("page_token", "")
      direction = params |> Map.get("direction", "next")

      fetch_branches =
        Async.run(fn ->
          params = [project_id: project.id, page_token: page_token, direction: direction]

          {wfs, next_page_token, previous_page_token} =
            Models.Workflow.list_latest_workflows(params)

          decorated_branches = Decorators.Branch.decorate_many(wfs)

          {decorated_branches, next_page_token, previous_page_token}
        end)

      {:ok, {branches, next_page_token, previous_page_token}} = Async.await(fetch_branches)

      case branches do
        [] ->
          if Models.Project.file_exists?(project.id, project.initial_pipeline_file) do
            render_default_branch(conn)
          else
            if FeatureProvider.feature_enabled?(:new_project_onboarding, param: project.org_id) do
              redirect(conn, to: project_onboarding_path(conn, :onboarding_index, project.name))
            else
              redirect(conn, to: project_onboarding_path(conn, :template, project.name))
            end
          end

        [branch | []] ->
          redirect(conn, to: branch_path(conn, :edit_workflow, branch.id))

        branches ->
          render_choose_branch(conn, branches, next_page_token, previous_page_token)
      end
    end)
  end

  defp render_default_branch(conn) do
    org_id = conn.assigns.organization_id
    project = conn.assigns.project
    user_id = conn.assigns.user_id

    user = Models.User.find(user_id)

    fetch_secrets =
      Async.run(fn -> Secret.list(user.id, org_id, project.id, :ORGANIZATION, true) end,
        metric: "workflow.edit.fetch_secrets"
      )

    fetch_deployment_targets =
      Async.run(fn -> Deployments.fetch_targets(project.id) end,
        metric: "workflow.edit.fetch_deployment_targets"
      )

    fetch_organization =
      Async.run(fn -> Organization.find(org_id) end, metric: "workflow.edit.fetch_organization")

    fetch_agent_types =
      Async.run(fn -> AgentType.list(org_id) end, metric: "workflow.edit.fetch_agent_types")

    fetch_self_hosted_agent_types =
      Async.run(fn -> Front.SelfHostedAgents.AgentType.list(org_id) end,
        metric: "workflow.edit.fetch_self_hosted_agent_types"
      )

    fetch_files_or_create_job =
      if FeatureProvider.feature_enabled?(:wf_editor_via_jobs, param: org_id) do
        job_params = %{
          user_id: user.id,
          project: project,
          target_branch: "default_branch",
          restricted_job: true,
          commit_sha: "",
          hook: %{
            name: "default_branch",
            type: :skip
          }
        }

        Async.run(fn -> FetchingJob.start_fetching_job(job_params) end,
          metric: "workflow.edit.start_job"
        )
      else
        Async.run(
          fn -> Repohub.fetch_semaphore_files(project.repo_id, project.initial_pipeline_file) end,
          metric: "workflow.edit.load_all_yaml_files"
        )
      end

    {:ok, secrets} = Async.await(fetch_secrets)
    {:ok, organization} = Async.await(fetch_organization)
    {:ok, {:ok, hosted_agent_types}} = Async.await(fetch_agent_types)
    {:ok, {:ok, self_hosted_agent_types}} = Async.await(fetch_self_hosted_agent_types)
    {:ok, {:ok, deployment_targets}} = Async.await(fetch_deployment_targets)

    {initial_yaml, yamls, job_id, alert} =
      if FeatureProvider.feature_enabled?(:wf_editor_via_jobs, param: org_id) do
        {:ok, {:ok, job_id}} = Async.await(fetch_files_or_create_job)
        {project.initial_pipeline_file, [], job_id, nil}
      else
        {:ok, {:ok, yaml_files}} = Async.await(fetch_files_or_create_job)

        {initial_yaml, yamls, alert} =
          extract_yamls(yaml_files, project.initial_pipeline_file, org_id)

        {initial_yaml, yamls, "", alert}
      end

    workflow_data = %{createdInEditor: false, initialYAML: initial_yaml, yamls: yamls}

    params = [
      title: "Edit workflow・#{project.name}・#{organization.name}",
      js: :workflow_editor,
      secrets: secrets,
      project: project,
      commiter_avatar: user.avatar_url,
      workflow_data: workflow_data,
      fetching_job_id: job_id,
      agent_types: combine_agent_types(hosted_agent_types, self_hosted_agent_types),
      deployment_targets: Enum.map(deployment_targets, & &1.name),
      hide_promotions: Application.get_env(:front, :hide_promotions, false)
    ]

    conn
    |> put_flash(:alert, alert)
    |> render("edit_workflow.html", params)
  end

  defp combine_agent_types(hosted_agent_types, self_hosted_agent_types) do
    self_hosted =
      self_hosted_agent_types
      |> Enum.map(fn a -> %{type: a.name, platform: "SELF_HOSTED", specs: "", os_image: ""} end)

    combined = hosted_agent_types.agent_types ++ self_hosted

    %{
      agent_types: combined,
      # We want new pipelines constructed through the Workflow Editor to use ubuntu2004
      # as the default OS image for Linux. However, to avoid breaking builds, Zebra still
      # uses ubuntu1804 as the default one if you don't specify anything in your YAML.
      # Once we deprecate the Ubuntu 18.04 image, we should be able to remove this hardcoded
      # value from here and use hosted_agent_types.default_linux_os_image again.
      default_linux_os_image: "ubuntu2004",
      default_mac_os_image: hosted_agent_types.default_mac_os_image
    }
  end

  defp extract_yamls([], _, org_id) do
    initial_yaml = ".semaphore/semaphore.yml"

    template = Front.WorkflowTemplate.simple(org_id)
    # uncomment when removing new_project_onboarding feature flag
    # |> Front.WorkflowTemplate.set_machine_type("f1-standard-2")
    # |> Front.WorkflowTemplate.set_os_image("ubuntu2204")

    files = %{initial_yaml => template}

    {initial_yaml, files,
     "We couldn't find any semaphore files for this workflow. So we are starting with an empty template."}
  end

  defp extract_yamls(files, initial_yaml, _org_id) when length(files) > 0 do
    files =
      files
      |> Enum.map(fn f -> {f.path, f.content} end)
      |> Enum.into(%{})

    {initial_yaml, files, nil}
  end

  defp render_choose_branch(conn, branches, next_page_token, previous_page_token) do
    conn
    |> render(
      "choose_branch.html",
      project: conn.assigns.project,
      branches: branches,
      next_page_token: next_page_token,
      previous_page_token: previous_page_token,
      first_page?: previous_page_token == "",
      last_page?: next_page_token == "",
      title: "Choose Branch・#{conn.assigns.project.name}"
    )
  end

  def blocked(conn, _prams) do
    Watchman.benchmark("project.blocked.duration", fn ->
      org_id = conn.assigns.organization_id
      project = conn.assigns.project

      fetch_organization = Async.run(fn -> Models.Organization.find(org_id) end)

      fetch_hooks = Async.run(fn -> Models.RepoProxy.list_blocked(project.id) end)

      {:ok, organization} = Async.await(fetch_organization)
      {:ok, hooks} = Async.await(fetch_hooks)

      hooks =
        Enum.map(hooks, fn hook ->
          %{
            display_name: hook.name,
            html_url: project_path(conn, :build_blocked, project.name, hook.id),
            icon: "#{FrontWeb.SharedHelpers.assets_path()}/images/icn-branch.svg"
          }
        end)

      conn
      |> render(
        "blocked.html",
        js: "blocked",
        project: project,
        organization: organization,
        hooks: hooks,
        title: "#{project.name}・#{organization.name}"
      )
    end)
  end

  def filtered_blocked(conn, params) do
    Watchman.benchmark("filtered_blocked.duration", fn ->
      project = conn.assigns.project
      name_contains = params["name_contains"]

      hooks = Models.RepoProxy.list_blocked(project.id, name_contains)

      hooks =
        Enum.map(hooks, fn hook ->
          %{
            display_name: hook.name,
            html_url: project_path(conn, :build_blocked, project.name, hook.id),
            icon: "#{FrontWeb.SharedHelpers.assets_path()}/images/icn-branch.svg"
          }
        end)

      conn
      |> json(hooks)
    end)
  end

  def build_blocked(conn, params) do
    Watchman.benchmark("project.build_blocked.duration", fn ->
      project = conn.assigns.project
      branch = params["branch"]
      hook_id = params["hook_id"]

      case Models.RepoProxy.build_blocked(project.id, hook_id) do
        {:ok, build} ->
          conn
          |> put_status(201)
          |> json(%{
            workflow_id: build.workflow_id,
            branch: branch,
            check_url: project_path(conn, :check_workflow, project.name),
            message: "Build scheduled. Waiting for Workflow to be started."
          })

        {:error, msg} ->
          conn
          |> put_status(422)
          |> json(%{error: msg})
      end
    end)
  end

  def commit_config(conn, params) do
    Watchman.benchmark("project.commit_config.duration", fn ->
      alias Front.Models.Repohub

      project = conn.assigns.project
      user_id = conn.assigns.user_id
      repository_id = project.repo_id
      branch = params["branch"]
      commit_message = params["commit_message"]

      conn
      |> Audit.new(:Project, :Modified)
      |> Audit.add(description: "Committed a new YAML to repository.")
      |> Audit.add(resource_id: project.id)
      |> Audit.add(resource_name: project.name)
      |> Audit.metadata(branch: branch, commit_message: commit_message)
      |> Audit.log()

      Logger.info(
        Enum.join(
          [
            "Committing to #{project.name}",
            "branch: #{branch}",
            "commit_message: #{commit_message}",
            "user_id: #{user_id}"
          ],
          ", "
        )
      )

      maybe_finish_onboarding = fn ->
        case project.state == :ONBOARDING do
          true -> Models.Project.finish_onboarding(conn.assigns.project.id)
          _ -> nil
        end
      end

      if FeatureProvider.feature_enabled?(:wf_editor_via_jobs, param: project.organization_id) do
        job_params = %{
          project: project,
          user_id: user_id,
          initial_branch: params["initial_branch"],
          target_branch: branch,
          commit_message: commit_message,
          changes: to_commit_request_changes(params)
        }

        case start_commit_job(job_params) do
          {:ok, job_id} ->
            Front.Async.run(maybe_finish_onboarding)

            msg = "Commiting changes to git repository."

            conn
            |> put_status(201)
            |> json(%{
              message: msg,
              branch: branch,
              wait:
                should_wait(
                  project.build_branches,
                  project.whitelist_branches,
                  project.branch_whitelist,
                  branch
                ),
              commit_sha: "",
              job_id: job_id
            })

          error ->
            send_response(error, conn)
        end
      else
        request =
          InternalApi.Repository.CommitRequest.new(
            repository_id: repository_id,
            user_id: user_id,
            branch_name: branch,
            commit_message: commit_message,
            changes: to_commit_request_changes(params)
          )

        case Repohub.commit(request) do
          {:ok, res} ->
            Front.Async.run(maybe_finish_onboarding)

            msg = "Config committed. Waiting for Workflow to start."

            conn
            |> put_status(201)
            |> json(%{
              message: msg,
              branch: branch,
              wait:
                should_wait(
                  project.build_branches,
                  project.whitelist_branches,
                  project.branch_whitelist,
                  branch
                ),
              commit_sha: res.revision.commit_sha,
              job_id: ""
            })

          {:error, message} ->
            conn |> put_status(422) |> json(%{error: message})
        end
      end
    end)
  end

  defp start_commit_job(params) do
    with {:ok, agent} <- CommitJob.get_agent(params.project),
         {:ok, creds} <- CommitJob.get_git_credentials(params.project, params.user_id),
         {:user, user} when user != nil <- {:user, User.find(params.user_id)},
         params <- Map.put(params, :user, user),
         params <- Map.put(params, :restricted_job, true),
         {:ok, job_spec} <- CommitJob.create_job_spec(agent, creds, params),
         {:ok, job} <- Job.create(job_spec, params) do
      {:ok, job.id}
    else
      error ->
        Logger.error(
          Enum.join(
            [
              "Could not create commit job",
              "project: #{params.project.id}",
              "branch: #{params.target_branch}",
              "commit_message: #{params.commit_message}",
              "user: #{params.user_id}",
              "error: #{inspect(error)}"
            ],
            ", "
          )
        )

        {:error, :commit_job_failed}
    end
  end

  def check_commit_job(conn, params) do
    project = conn.assigns.project
    job_id = params["job_id"]

    job_id
    |> find_job(project)
    |> fetch_commit_sha(project)
    |> send_response(conn)
  end

  def fetch_yaml_artifacts(conn, params) do
    project = conn.assigns.project
    job_id = params["job_id"]

    find_job(job_id, project)
    |> fetch_yamls_for_job(project.id)
    |> case do
      {:ok, urls, finished} ->
        conn
        |> put_status(200)
        |> json(%{signed_urls: urls, finished: finished})

      {:error, e} ->
        Logger.error(
          "Failed to fetch YAMLs for job #{job_id}, project #{project.id}: #{inspect(e)}"
        )

        message = "Failed to fetch Semaphore YAML files from the git repository."
        message = message <> " Please, contact support."

        conn |> put_status(422) |> json(%{error: message})
    end
  end

  defp find_job(job_id, project) do
    case Job.find(job_id) do
      nil ->
        Logger.error(
          Enum.join(
            [
              "Could not find commit job with given job id",
              "project: #{project.id}",
              "commit job id: #{job_id}"
            ],
            ", "
          )
        )

        {:error, :commit_job_failed}

      {:error, :grpc_req_failed} ->
        {:error, :commit_job_failed}

      job ->
        {:ok, job}
    end
  end

  defp fetch_commit_sha({:ok, %{id: job_id, state: "passed"}}, project) do
    path = ".workflow_editor/commit_sha.val"

    case Artifacthub.fetch_file(project.artifact_store_id, "jobs", job_id, path) do
      {:ok, content} ->
        {:ok, String.trim(content)}

      {:error, er_msg} ->
        Logger.error(
          Enum.join(
            [
              "Failed to fetch commit_sha from artifacts",
              "project: #{project.id}",
              "commit job id: #{job_id}",
              "error: #{inspect(er_msg)}"
            ],
            ", "
          )
        )

        {:error, :commit_job_failed}
    end
  end

  defp fetch_commit_sha({:ok, %{id: job_id, state: state}}, project)
       when state in ["failed", "stopped"] do
    Logger.error(
      Enum.join(
        [
          "Commit job has failed",
          "project: #{project.id}",
          "commit job id: #{job_id}"
        ],
        ", "
      )
    )

    {:error, :commit_job_failed}
  end

  defp fetch_commit_sha({:ok, _job}, _project), do: {:ok, ""}

  defp fetch_commit_sha(error = {:error, _}, _project), do: error

  defp send_response({:ok, commit_sha}, conn) do
    conn |> put_status(200) |> json(%{commit_sha: commit_sha})
  end

  defp send_response({:error, :commit_job_failed}, conn) do
    message = "Failed to commit changes to git repository."
    message = message <> " Please, contact support."

    conn |> put_status(422) |> json(%{error: message})
  end

  defp fetch_yamls_for_job({:ok, %{id: job_id, state: "passed"}}, project_id) do
    case Artifacthub.list_and_sign_urls(project_id, "jobs", job_id, @yaml_artifact_directory) do
      {:ok, urls} ->
        updated_urls =
          Enum.reduce(urls, %{}, fn {path, url}, acc ->
            new_path = String.replace_prefix(path, ".workflow_editor/", "")
            Map.put(acc, new_path, url)
          end)

        {:ok, updated_urls, true}

      error ->
        error
    end
  end

  defp fetch_yamls_for_job({:ok, %{state: state}}, _) when state in ["pending", "running"],
    do: {:ok, %{}, false}

  defp fetch_yamls_for_job({:ok, %{state: state}}, _) when state in ["failed", "stopped"],
    do: {:error, "Job for fetching YAMLs failed"}

  defp fetch_yamls_for_job(e, _), do: e

  def check_workflow(conn, params) do
    project = conn.assigns.project
    branch = params["branch"] || project.repo_default_branch
    commit_sha = params["commit_sha"]

    workflow_url =
      if params["commit_sha"] != "" do
        workflow =
          Models.Workflow.find_latest(
            project_id: project.id,
            branch_name: branch,
            commit_sha: commit_sha
          )

        if workflow do
          workflow_path(conn, :show, workflow.id, pipeline_id: workflow.root_pipeline_id)
        end
      end

    artifact_url =
      if params["job_id"] do
        job = Job.find(params["job_id"])

        if job && job.state == "passed" do
          {:ok, url} =
            Artifacthub.signed_url(project.id, "jobs", job.id, ".workflow_editor/commit_sha.val")

          url
        end
      end

    conn
    |> put_status(200)
    |> json(%{
      workflow_url: workflow_url,
      artifact_url: artifact_url
    })
  end

  def queues(conn, _params) do
    Watchman.benchmark("refresh_workflows.duration", fn ->
      project = conn.assigns.project

      queues =
        project.id
        |> Models.Queue.list_with_latest_pipeline()
        |> Models.Queue.preload_latest_hooks()

      conn
      |> put_layout(false)
      |> render(
        "_queues.html",
        queues: queues,
        project: project
      )
    end)
  end

  def filtered_branches(conn, params) do
    Watchman.benchmark("filter_branches.duration", fn ->
      project = conn.assigns.project
      name_contains = params["name_contains"]
      with_archived = params["with_archived"] == "true"
      types = params["types"]

      {branches, _} =
        Models.Branch.list(
          project_id: project.id,
          with_archived: with_archived,
          name_contains: name_contains,
          types: types,
          page_size: 50
        )

      branches =
        Enum.map(branches, fn branch ->
          Map.take(branch, [:id, :display_name, :name, :html_url, :type])
        end)

      conn
      |> json(branches)
    end)
  end

  @max_page_size 2000
  def filtered_new_owners(conn, params) do
    Watchman.benchmark("filtered_new_owners.duration", fn ->
      org_id = conn.assigns.organization_id

      {:ok, {members, _total_pages}} =
        Front.RBAC.Members.list_org_members(org_id,
          username: params["name_contains"],
          page_size: @max_page_size
        )

      users =
        Enum.map(members, fn member ->
          %{
            id: member.id,
            display_name: member.name,
            avatar_url: member.avatar
          }
        end)

      conn
      |> json(users)
    end)
  end

  # Private

  defp maybe_redirect_to_onboarding(conn, _params) do
    project = conn.assigns.project

    if FeatureProvider.feature_enabled?(:new_project_onboarding, param: project.organization_id) do
      case project.state do
        :ONBOARDING ->
          conn
          |> redirect(
            to:
              project_onboarding_path(conn, :onboarding_index, project.name, [
                "existing_configuration"
              ])
          )
          |> halt()

        _ ->
          conn
      end
    else
      conn
    end
  end

  defp member(conn, params) do
    org_id = conn.assigns.organization_id
    user_id = conn.assigns.user_id
    project = conn.assigns.project

    params =
      struct!(Front.ProjectPage.Model.LoadParams,
        project_id: project.id,
        organization_id: org_id,
        user_id: user_id,
        page_token: params["page_token"] || "",
        direction: params["direction"] || "",
        list_mode: workflow_list_mode_setting(conn),
        user_page?: user_page?(conn),
        ref_types: ref_types(conn)
      )

    {:ok, model, page_source} =
      Front.Tracing.track(conn.assigns.trace_id, "fetch_project_page_model", fn ->
        params |> Front.ProjectPage.Model.get(force_cold_boot: conn.params["force_cold_boot"])
      end)

    assigns =
      %{
        js: :project_page,
        project: model.project,
        organization: model.organization,
        permissions: conn.assigns.permissions,
        title: "#{model.project.name}・#{model.organization.name}",
        pagination: model.pagination,
        pollman: pollman(conn, model),
        filters: filters(conn),
        branches: model.branches,
        type: workflow_list_type_setting(conn),
        requester: model.user_page?,
        listing: model.list_mode,
        listing_requester: combined_listing_requester(model.list_mode, model.user_page?),
        all_pipelines_enabled: show_all_pipelines?(conn),
        notice: conn |> get_flash(:notice),
        social_metatags: true,
        workflows: model.workflows
      }
      |> put_private_layout_assigns(conn)

    conn
    |> put_page_source_header(page_source)
    |> render(
      "private.html",
      assigns
    )
  end

  defp put_private_layout_assigns(assigns, conn) do
    org_id = conn.assigns.organization_id
    user_id = conn.assigns.user_id
    project = conn.assigns.project

    starred? =
      Front.Tracing.track(conn.assigns.trace_id, "check_if_project_is_starred", fn ->
        Watchman.benchmark("project_page_check_star", fn ->
          Models.User.has_favorite(user_id, org_id, project.id)
        end)
      end)

    assigns
    |> Map.put(:starred?, starred?)
    |> Map.put(:layout, {FrontWeb.LayoutView, "project.html"})
    |> Front.Breadcrumbs.Project.construct(conn, :project)
  end

  defp guest(conn, params) do
    user_id = conn.assigns.user_id || ""
    org_id = conn.assigns.organization_id
    project = conn.assigns.project

    ## in case of public page `requester` (`user_page?`) is set to `false`

    params =
      struct!(Front.ProjectPage.Model.LoadParams,
        project_id: project.id,
        organization_id: org_id,
        user_id: user_id,
        page_token: params["page_token"] || "",
        direction: params["direction"] || "",
        list_mode: workflow_list_mode_setting(conn),
        user_page?: false,
        ref_types: ref_types(conn)
      )

    {:ok, data, :from_api} = params |> Front.ProjectPage.Model.load_from_api()

    pollman = %{
      state: "poll",
      href: "/projects/#{project.id}/workflows",
      params: [
        requester: data.user_page?,
        page_token: params.page_token,
        direction: params.direction,
        listing: data.list_mode || workflow_list_mode_setting(conn)
      ]
    }

    conn
    |> render(
      "public.html",
      js: :project_page,
      project: data.project,
      organization: data.organization,
      filters: filters(conn),
      branches: data.branches,
      workflows: data.workflows,
      pagination: data.pagination,
      pollman: pollman,
      title: "#{project.name}・#{data.organization.name}",
      requester: data.user_page?,
      listing: data.list_mode,
      listing_requester: combined_listing_requester(data.list_mode, data.user_page?),
      all_pipelines_enabled: show_all_pipelines?(conn),
      type: workflow_list_type_setting(conn),
      notice: conn |> get_flash(:notice),
      social_metatags: true
    )
  end

  defp put_page_source_header(conn, source) do
    case source do
      :from_cache -> conn |> put_resp_header("semaphore_page_source", "cache")
      :from_api -> conn |> put_resp_header("semaphore_page_source", "API")
    end
  end

  defp pollman(conn, model) do
    memory = conn.req_cookies["memory"] |> MemoryCookie.values()

    %{
      state: "poll",
      href: "/projects/#{model.project.name}/workflows",
      params: [
        requester: user_page?(conn),
        page_token: conn.params["page_token"] || "",
        direction: conn.params["direction"] || "",
        type: conn.params["type"] || memory["projectType"],
        listing: model.list_mode || workflow_list_mode_setting(conn)
      ]
    }
  end

  defp workflow_list_type_setting(conn) do
    memory = conn.req_cookies["memory"] |> MemoryCookie.values()

    conn.params["type"] || memory["projectType"]
  end

  defp workflow_list_mode_setting(conn) do
    memory = conn.req_cookies["memory"] |> MemoryCookie.values()

    requested_mode = conn.params["listing"] || memory["projectListing"] || "all_pipelines"

    if show_all_pipelines?(conn) do
      normalize_list_mode(requested_mode)
    else
      "latest"
    end
  end

  defp normalize_list_mode("all_pipelines"), do: "all_pipelines"
  defp normalize_list_mode(_), do: "latest"

  defp show_all_pipelines?(conn) do
    FeatureProvider.feature_enabled?(:project_page_all_pipelines,
      param: conn.assigns.organization_id
    )
  end

  defp filters(conn) do
    list_mode = workflow_list_mode_setting(conn)
    requester? = user_page?(conn)

    %{
      type: workflow_list_type_setting(conn),
      requester: requester?,
      listing: list_mode,
      listing_requester: combined_listing_requester(list_mode, requester?)
    }
  end

  defp combined_listing_requester(_, true), do: "all_by_me"
  defp combined_listing_requester("all_pipelines", _), do: "all_pipelines"
  defp combined_listing_requester(_, _), do: "latest_per_branch"

  defp ref_types(conn) do
    conn |> workflow_list_type_setting() |> String.split(",", trim: true)
  end

  defp user_page?(conn) do
    memory = conn.req_cookies["memory"] |> MemoryCookie.values()

    workflow_list_mode_setting(conn) != "latest" &&
      !is_nil(conn.assigns.user_id) &&
      (conn.params["requester"] == "true" || memory["projectRequester"] == "true")
  end

  # Utility for constructing a commit payload from Phoenix params.
  # Used in commit_config.
  # sobelow_skip ["Traversal.FileModule"]
  defp to_commit_request_changes(params) do
    alias InternalApi.Repository.CommitRequest.Change

    added =
      Enum.map(params["added_files"] || [], fn
        %{filename: filename, path: path} ->
          to_commit_change(:ADD_FILE, filename, File.read!(path))

        %{filename: filename, content: content} ->
          to_commit_change(:ADD_FILE, filename, content)
      end)

    modified =
      Enum.map(params["modified_files"] || [], fn
        %{filename: filename, path: path} ->
          to_commit_change(:MODIFY_FILE, filename, File.read!(path))

        %{filename: filename, content: content} ->
          to_commit_change(:MODIFY_FILE, filename, content)
      end)

    deleted =
      Enum.map(params["deleted_files"] || [], fn f ->
        to_commit_change(:DELETE_FILE, f.filename, "")
      end)

    added ++ modified ++ deleted
  end

  defp to_commit_change(type, filename, content) do
    alias InternalApi.Repository.CommitRequest.Change

    Change.new(
      action: Change.Action.value(type),
      file: InternalApi.Repository.File.new(path: filename, content: content)
    )
  end

  defp should_wait(build_branches, use_whitelist, whitelist, branch) do
    build_branches and (not use_whitelist or String.contains?(whitelist, branch))
  end
end
