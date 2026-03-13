defmodule FrontWeb.WorkflowController do
  use FrontWeb, :controller
  import Phoenix.HTML.Link

  require Logger

  alias Front.TaskSupervisor

  alias Front.Models.{
    AgentType,
    Branch,
    Deployments,
    Organization,
    Repohub,
    RepoProxy,
    Secret,
    User,
    FetchingJob
  }

  alias Front.Async
  alias Front.Audit

  alias FrontWeb.Plugs.{
    FetchPermissions,
    Header,
    PageAccess,
    PublicPageAccess,
    PutProjectAssigns
  }

  plug(PutProjectAssigns)
  plug(FetchPermissions, scope: "project")

  plug(PublicPageAccess when action in [:show, :status])
  plug(PageAccess, [permissions: "project.view"] when action not in [:show, :status])
  plug(PageAccess, [permissions: "project.workflow.manage"] when action in [:edit])
  plug(PageAccess, [permissions: "project.job.rerun"] when action in [:rebuild])

  plug(Header when action in [:show, :edit])

  def edit(conn, _params) do
    Watchman.benchmark("workflow.edit.duration", fn ->
      project = conn.assigns.project
      user = User.find(conn.assigns.user_id)

      org_id = conn.assigns.organization_id
      hook_id = conn.assigns.workflow.hook_id

      fetch_org_secrets =
        Async.run(fn -> Secret.list(user.id, org_id, project.id, :ORGANIZATION, true) end,
          metric: "workflow.edit.fetch_secrets"
        )

      fetch_project_secrets =
        Async.run(fn -> Secret.list(user.id, org_id, project.id, :PROJECT, true) end,
          metric: "workflow.edit.fetch_project_secrets"
        )

      fetch_deployment_targets =
        Async.run(fn -> Deployments.fetch_targets(project.id) end,
          metric: "workflow.edit.fetch_deployment_targets"
        )

      fetch_organization =
        Async.run(fn -> Organization.find(org_id) end, metric: "workflow.edit.fetch_organization")

      fetch_hook =
        Async.run(fn -> RepoProxy.find(hook_id) end, metric: "workflow.edit.fetch_hook")

      fetch_agent_types =
        Async.run(fn -> AgentType.list(org_id) end, metric: "workflow.edit.fetch_agent_types")

      fetch_self_hosted_agent_types =
        Async.run(fn -> Front.SelfHostedAgents.AgentType.list(org_id) end,
          metric: "workflow.edit.fetch_self_hosted_agent_types"
        )

      {:ok, hook} = Async.await(fetch_hook)

      fetch_files_or_create_job =
        if FeatureProvider.feature_enabled?(:wf_editor_via_jobs, param: org_id) do
          job_params = %{
            user_id: user.id,
            project: project,
            target_branch: hook.branch_name,
            restricted_job: true,
            commit_sha: hook.head_commit_sha,
            hook: hook
          }

          Async.run(fn -> FetchingJob.start_fetching_job(job_params) end,
            metric: "workflow.edit.start_job"
          )
        else
          Async.run(
            fn -> fetch_yaml_files(project.repo_id, hook, project.initial_pipeline_file) end,
            metric: "workflow.edit.load_all_yaml_files"
          )
        end

      {:ok, org_secrets} = Async.await(fetch_org_secrets)
      {:ok, project_secrets} = Async.await(fetch_project_secrets)
      {:ok, organization} = Async.await(fetch_organization)
      {:ok, {:ok, hosted_agent_types}} = Async.await(fetch_agent_types)
      {:ok, {:ok, self_hosted_agent_types}} = Async.await(fetch_self_hosted_agent_types)
      {:ok, {:ok, deployment_targets}} = Async.await(fetch_deployment_targets)

      fetch_result =
        if FeatureProvider.feature_enabled?(:wf_editor_via_jobs, param: org_id) do
          fetching_job_result(
            fetch_files_or_create_job,
            hook,
            project.initial_pipeline_file
          )
        else
          fetching_files_result(
            fetch_files_or_create_job,
            hook,
            org_id,
            project.initial_pipeline_file
          )
        end

      case fetch_result do
        {:error, error_message} ->
          conn
          |> put_flash(:alert, error_message)
          |> redirect(to: project_path(conn, :show, project.name))
          |> halt()

        {:ok, {initial_yaml, yamls, job_id, alert}} ->
          workflow_data = %{createdInEditor: false, initialYAML: initial_yaml, yamls: yamls}

          params = [
            title: "Edit workflow・#{hook.name}・#{project.name}・#{organization.name}",
            js: :workflow_editor,
            org_secrets: org_secrets,
            project_secrets: project_secrets,
            project: project,
            hook: hook,
            sidebar_selected_item: project.id,
            commiter_avatar: user.avatar_url,
            workflow_data: workflow_data,
            fetching_job_id: job_id,
            agent_types: combine_agent_types(hosted_agent_types, self_hosted_agent_types),
            deployment_targets: Enum.map(deployment_targets, & &1.name),
            hide_promotions: Application.get_env(:front, :hide_promotions, false)
          ]

          conn
          |> put_flash(:alert, alert)
          |> render("edit.html", params)
      end
    end)
  end

  defp fetch_yaml_files(repo_id, hook, initial_yaml) do
    cond do
      hook.type == "pr" and hook.forked_pr ->
        Repohub.fetch_semaphore_files(
          repo_id,
          initial_yaml,
          hook.pr_sha,
          "refs/pulls/#{hook.pr_number}/head"
        )

      hook.type == "pr" and !hook.forked_pr ->
        Repohub.fetch_semaphore_files(
          repo_id,
          initial_yaml,
          hook.pr_sha,
          "refs/heads/#{hook.pr_branch_name}"
        )

      hook.type == "branch" ->
        Repohub.fetch_semaphore_files(
          repo_id,
          initial_yaml,
          hook.head_commit_sha,
          "refs/heads/#{hook.branch_name}"
        )

      hook.type == "tag" ->
        Repohub.fetch_semaphore_files(
          repo_id,
          initial_yaml,
          hook.head_commit_sha,
          "refs/tags/#{hook.tag_name}"
        )
    end
  end

  # sobelow_skip ["Traversal.FileModule"]
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

  defp fetching_job_result(fetch_files_or_create_job, hook, initial_yaml) do
    case Async.await(fetch_files_or_create_job) do
      {:ok, {:ok, job_id}} ->
        {:ok, {initial_yaml, %{}, job_id, nil}}

      {:ok, {:error, %GRPC.RPCError{} = error}} ->
        {:error, workflow_files_error_message(error, hook)}

      {:ok, {:error, reason}} ->
        Logger.warn("[workflow.edit] Unable to start fetching job: #{inspect(reason)}")
        {:error, workflow_files_error_message(reason, hook)}

      {:exit, reason} ->
        Logger.warn("[workflow.edit] Fetching job crashed: #{inspect(reason)}")
        {:error, workflow_files_error_message(reason, hook)}
    end
  end

  defp fetching_files_result(fetch_files_or_create_job, hook, org_id, initial_yaml) do
    case Async.await(fetch_files_or_create_job) do
      {:ok, {:ok, yaml_files}} ->
        {yaml_path, yamls, alert} = extract_yamls(yaml_files, initial_yaml, org_id)
        {:ok, {yaml_path, yamls, "", alert}}

      {:ok, {:error, %GRPC.RPCError{} = error}} ->
        {:error, workflow_files_error_message(error, hook)}

      {:ok, {:error, reason}} ->
        Logger.warn("[workflow.edit] Unable to load workflow files: #{inspect(reason)}")
        {:error, workflow_files_error_message(reason, hook)}

      {:exit, reason} ->
        Logger.warn("[workflow.edit] Fetching workflow files crashed: #{inspect(reason)}")
        {:error, workflow_files_error_message(reason, hook)}
    end
  end

  defp workflow_files_error_message(%GRPC.RPCError{message: message}, hook) do
    if String.contains?(message, "couldn't find remote ref") do
      "We couldn't load workflow files because #{workflow_reference_label(hook)} no longer exists."
    else
      "We couldn't load workflow files. Please try again."
    end
  end

  defp workflow_files_error_message(_error, _hook) do
    "We couldn't load workflow files. Please try again."
  end

  defp workflow_reference_label(hook) do
    case hook.type do
      "branch" -> "the branch \"#{hook.branch_name}\""
      "tag" -> "the tag \"#{hook.tag_name}\""
      "pr" -> "the pull request branch \"#{hook.pr_branch_name}\""
      _ -> "the selected reference"
    end
  end

  def rebuild(conn, _params) do
    alias Google.Rpc.Code
    alias InternalApi.PlumberWF.RescheduleRequest
    alias InternalApi.PlumberWF.WorkflowService.Stub

    Logger.debug(fn -> "Received rebuild request for workflow #{conn.assigns.workflow.id}" end)

    {:ok, channel} =
      GRPC.Stub.connect(Application.fetch_env!(:front, :workflow_api_grpc_endpoint))

    request = %RescheduleRequest{
      wf_id: conn.assigns.workflow.id,
      requester_id: conn.assigns.user_id,
      request_token: UUID.uuid4()
    }

    log_rebuild(conn, conn.assigns.project, conn.assigns.workflow)

    Logger.debug(fn -> "Sending Reschedule request: #{inspect(request)}" end)

    options = [
      timeout: 30_000
    ]

    {:ok, response} = Stub.reschedule(channel, request, options)
    Logger.debug(fn -> "Received reschedule response #{inspect(response)}" end)

    case Code.key(response.status.code) do
      :OK ->
        conn
        |> redirect(to: workflow_path(conn, :show, response.wf_id, pipeline_id: response.ppl_id))

      :RESOURCE_EXHAUSTED ->
        conn
        |> put_flash(:alert, [
          "You reached a limit for a number of enqueued pipelines in a queue. Read more about abuse protection ",
          link("in our docs",
            to:
              "https://docs.#{Application.fetch_env!(:front, :domain)}/reference/quotas-and-limits"
          ),
          "."
        ])
        |> redirect(
          to:
            workflow_path(conn, :show, conn.assigns.workflow.id,
              pipeline_id: conn.assigns.workflow.root_pipeline_id
            )
        )
    end
  end

  defp log_rebuild(conn, project, workflow) do
    conn
    |> Audit.new(:Workflow, :Rebuild)
    |> Audit.add(:resource_name, workflow.id)
    |> Audit.add(:description, "Rebuilt the workflow")
    |> Audit.metadata(project_id: project.id)
    |> Audit.metadata(project_name: project.name)
    |> Audit.metadata(branch_name: workflow.branch_name)
    |> Audit.metadata(workflow_id: workflow.id)
    |> Audit.metadata(commit_sha: workflow.commit_sha)
    |> Audit.log()
  end

  def show(conn, params) do
    Watchman.benchmark("show.duration", fn ->
      case conn.assigns.authorization do
        :member -> common(conn, "member.html", params)
        :guest -> common(conn, "guest.html", params)
      end
    end)
  end

  # sobelow_skip ["Traversal.FileModule"]
  defp common(conn, template, params) do
    notice = conn |> get_flash(:notice)
    alert = conn |> get_flash(:alert)
    fork = params["fork"] == "true"
    close_fork_explanation = conn.req_cookies["close_fork_explanation"] == "true"

    fetch_organization =
      Task.Supervisor.async_nolink(TaskSupervisor, fn ->
        Organization.find(conn.assigns.organization_id)
      end)

    fetch_branch =
      Task.Supervisor.async_nolink(TaskSupervisor, fn ->
        Branch.find(
          conn.assigns.workflow.project_id,
          conn.assigns.workflow.branch_name
        )
      end)

    fetch_hook =
      Task.Supervisor.async_nolink(TaskSupervisor, fn ->
        RepoProxy.find(conn.assigns.workflow.hook_id)
      end)

    {:ok, organization} = Task.yield(fetch_organization)
    {:ok, branch} = Task.yield(fetch_branch)
    {:ok, hook} = Task.yield(fetch_hook)

    assigns =
      %{
        organization: organization,
        project: conn.assigns.project,
        branch: branch,
        hook: hook,
        title: compose_title(hook, branch, conn.assigns.project, organization),
        workflow: conn.assigns.workflow,
        selected_pipeline_id:
          conn.params["pipeline_id"] || conn.assigns.workflow.root_pipeline_id,
        workflow_tip: conn.req_cookies["#{conn.assigns.project.name}-workflow-tip"],
        notice: notice,
        alert: alert,
        permissions: conn.assigns.permissions,
        showForkExplanation?: fork && !close_fork_explanation,
        js: :workflow_view
      }
      |> put_layout_assigns(conn, template)

    render(
      conn,
      template,
      assigns
    )
  end

  defp put_layout_assigns(assigns, conn, template) do
    case template do
      "member.html" ->
        assigns
        |> Map.put(:layout, {FrontWeb.LayoutView, "workflow.html"})
        |> Front.Breadcrumbs.Workflow.construct(conn, workflow_name(assigns.hook))

      "guest.html" ->
        assigns
    end
  end

  def status(conn, params) do
    Watchman.benchmark("status.duration", fn ->
      workflow = conn.assigns.workflow

      data =
        [
          workflow: workflow,
          pipelines: workflow.pipelines,
          selected_pipeline_id: params["pipeline_id"],
          selected_pipeline:
            workflow.pipelines |> Enum.find(fn ppl -> ppl.id == params["pipeline_id"] end)
        ]
        |> inject_nonce(params)

      conn
      |> put_layout(false)
      |> render("_status.html", data)
    end)
  end

  defp compose_title(hook, nil, project, organization) do
    "#{workflow_name(hook)}・#{project.name}・#{organization.name}"
  end

  defp compose_title(hook, branch, project, organization) do
    "#{workflow_name(hook)}・#{branch.name}・#{project.name}・#{organization.name}"
  end

  defp workflow_name(hook) do
    hook.commit_message |> String.split("\n") |> hd
  end

  defp combine_agent_types(hosted_agent_types, self_hosted_agent_types) do
    self_hosted =
      self_hosted_agent_types
      |> Enum.map(fn a ->
        %{type: a.name, platform: "SELF_HOSTED", specs: "", os_image: "", state: "ENABLED"}
      end)

    combined = hosted_agent_types.agent_types ++ self_hosted

    %{
      agent_types: combined,
      # We want new pipelines constructed through the Workflow Editor to use ubuntu2204
      # as the default OS image for Linux. However, to avoid breaking builds, Zebra still
      # uses ubuntu1804 as the default one if you don't specify anything in your YAML.
      # Once we deprecate the Ubuntu 18.04 image, we should be able to remove this hardcoded
      # value from here and use hosted_agent_types.default_linux_os_image again.
      default_linux_os_image: "ubuntu2204",
      default_mac_os_image: hosted_agent_types.default_mac_os_image
    }
  end

  defp inject_nonce(data, %{"nonce" => nonce}),
    do: Keyword.merge([script_src_nonce: nonce], data)

  defp inject_nonce(data, _), do: data
end
