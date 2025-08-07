# credo:disable-for-this-file Credo.Check.Design.DuplicatedCode
defmodule Front.Models.Project do
  use Ecto.Schema
  import Ecto.Changeset

  alias Front.Sufix

  alias InternalApi.Projecthub
  alias InternalApi.Projecthub.{DestroyRequest, RequestMeta, UpdateRequest}
  alias InternalApi.Projecthub.Project.{Metadata, Spec, Spec.Repository}
  alias InternalApi.Projecthub.Project.Spec.PermissionType
  alias InternalApi.Projecthub.Project.Spec.Repository.{ForkedPullRequests, RunType, Whitelist}
  alias InternalApi.Projecthub.ProjectService.Stub

  require Logger

  @type t :: %__MODULE__{}

  @initial_semaphore_yaml_path ".semaphore/semaphore.yml"

  embedded_schema do
    field(:name, :string)
    field(:owner_id, :binary_id)
    field(:organization_id, :binary_id)
    field(:description, :string, default: "")
    field(:created_at, :utc_datetime)
    field(:repo_id, :string)
    field(:repo_owner, :string)
    field(:repo_name, :string)
    field(:repo_url, :string)
    field(:repo_public, :boolean)
    field(:repo_connected, :boolean)
    field(:repo_default_branch, :string)
    field(:run, :boolean)
    field(:build_branches, :boolean)
    field(:whitelist_branches, :boolean)
    field(:branch_whitelist, :string)
    field(:build_tags, :boolean)
    field(:whitelist_tags, :boolean)
    field(:tag_whitelist, :string)
    field(:build_prs, :boolean)
    field(:build_forked_prs, :boolean)
    field(:build_draft_prs, :boolean, default: true)
    field(:expose_secrets, :boolean)
    field(:allowed_secrets, :string)
    field(:filter_contributors, :boolean)
    field(:allowed_contributors, :string)
    field(:initial_pipeline_file, :string)
    field(:public, :boolean)

    field(:custom_permissions, :boolean)
    field(:allow_debug_default_branch, :boolean)
    field(:allow_debug_non_default_branch, :boolean)
    field(:allow_debug_pr, :boolean)
    field(:allow_debug_forked_pr, :boolean)
    field(:allow_debug_tag, :boolean)
    field(:allow_debug_empty_session, :boolean)
    field(:allow_attach_default_branch, :boolean)
    field(:allow_attach_non_default_branch, :boolean)
    field(:allow_attach_pr, :boolean)
    field(:allow_attach_forked_pr, :boolean)
    field(:allow_attach_tag, :boolean)

    field(:state, :string)
    field(:state_reason, :string)
    field(:cache_state, :string)
    field(:artifact_store_state, :string)
    field(:repository_state, :string)
    field(:permissions_state, :string)
    field(:analysis_state, :string)

    field(:cache_id, :string)
    field(:artifact_store_id, :string)

    field(:integration_type, :string)
    field(:commit_status, :map)
  end

  @required_fields [:name, :initial_pipeline_file]
  @optional_fields [
    :run,
    :build_branches,
    :build_tags,
    :build_prs,
    :build_forked_prs,
    :build_draft_prs,
    :custom_permissions,
    :allow_debug_empty_session,
    :allow_debug_default_branch,
    :allow_debug_non_default_branch,
    :allow_debug_pr,
    :allow_debug_forked_pr,
    :allow_debug_tag,
    :allow_attach_default_branch,
    :allow_attach_non_default_branch,
    :allow_attach_pr,
    :allow_attach_forked_pr,
    :allow_attach_tag,
    :expose_secrets,
    :allowed_secrets,
    :filter_contributors,
    :allowed_contributors,
    :whitelist_branches,
    :branch_whitelist,
    :whitelist_tags,
    :tag_whitelist,
    :public,
    :description,
    :repo_url
  ]

  def initial_semaphore_yaml_path, do: @initial_semaphore_yaml_path
  @project_name_cache_ttl :timer.hours(1)

  def changeset(project, params \\ %{}) do
    project
    |> cast(params, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields, message: "Cannot be empty")
    |> validate_format(:name, ~r/\A[\w\-\.]+\z/,
      message: "Project name can have only alphanumeric characters, underscore and dash"
    )
    |> validate_run_on_table
    |> validate_branch_whitelists
    |> validate_tag_whitelists
    |> validate_exposed_secrets
    |> validate_contributors
    |> validate_commit_status
  end

  def owner_changeset(project, params \\ %{}) do
    project
    |> cast(params, [:owner_id])
    |> validate_required([:owner_id], message: "Cannot be empty")
  end

  def initial_pipeline_file_changeset(project, file_path) do
    project
    |> cast(%{initial_pipeline_file: file_path}, [:initial_pipeline_file])
    |> validate_required(@required_fields, message: "Cannot be empty")
  end

  def find(name_or_id, org_id, _metadata \\ nil) do
    Watchman.benchmark("fetch_project.duration", fn ->
      case find_by_name(name_or_id, org_id) do
        nil -> find_by_id(name_or_id, org_id)
        project -> project
      end
    end)
  end

  def fork_and_create(org_id, owner_id, fork, iteration \\ 0) do
    case fork_and_create_req(org_id, owner_id, fork, iteration) do
      {:ok, project} ->
        {:ok, project}

      {:error, msg} ->
        next_iteration = iteration + 1

        if String.contains?(msg, "is already taken") && Sufix.contains?(next_iteration) do
          fork_and_create(org_id, owner_id, fork, next_iteration)
        else
          {:error, msg}
        end
    end
  end

  defp fork_and_create_req(org_id, owner_id, fork, iteration) do
    Watchman.benchmark("fork_and_create_project.duration", fn ->
      req =
        Projecthub.ForkAndCreateRequest.new(
          metadata: Projecthub.RequestMeta.new(org_id: org_id, user_id: owner_id),
          project: construct_project(fork.name, fork.url, fork.integration_type, iteration)
        )

      Logger.info("Request: #{inspect(req)}")

      {:ok, res} = Stub.fork_and_create(channel(), req, options())

      case Projecthub.ResponseMeta.Code.key(res.metadata.status.code) do
        :OK ->
          {:ok, construct(res.project)}

        _ ->
          Logger.info("Response: #{inspect(res)}")
          {:error, res.metadata.status.message}
      end
    end)
  end

  def create(org_id, owner_id, name, repo_url, integration_type, iteration \\ 0) do
    case create_req(org_id, owner_id, name, repo_url, integration_type, iteration) do
      {:ok, project} ->
        {:ok, project}

      {:error, msg} ->
        next_iteration = iteration + 1

        if String.contains?(msg, "is already taken") && Sufix.contains?(next_iteration) do
          create(org_id, owner_id, name, repo_url, integration_type, next_iteration)
        else
          {:error, msg}
        end
    end
  end

  defp create_req(org_id, owner_id, name, repo_url, integration_type, iteration) do
    Watchman.benchmark("create_project.duration", fn ->
      req =
        Projecthub.CreateRequest.new(
          metadata: Projecthub.RequestMeta.new(org_id: org_id, user_id: owner_id),
          project: construct_project(name, repo_url, integration_type, iteration)
        )

      Logger.info("Request: #{inspect(req)}")

      {:ok, res} = Stub.create(channel(), req, options())

      case Projecthub.ResponseMeta.Code.key(res.metadata.status.code) do
        :OK ->
          {:ok, construct(res.project)}

        _ ->
          Logger.info("Response: #{inspect(res)}")
          {:error, res.metadata.status.message}
      end
    end)
  end

  defp construct_project(name, repo_url, integration_type, iteration) do
    alias InternalApi.Projecthub.Project
    alias InternalApi.Projecthub.Project.Spec.Repository.RunType

    Project.new(
      metadata: Project.Metadata.new(name: name |> Sufix.with_sufix(iteration)),
      spec:
        Project.Spec.new(
          repository:
            Project.Spec.Repository.new(
              integration_type: map_integration_type(integration_type),
              url: repo_url,
              run_on: [
                RunType.value(:TAGS),
                RunType.value(:BRANCHES),
                RunType.value(:DRAFT_PULL_REQUESTS)
              ],
              run_present: {:run, true}
            )
        )
    )
  end

  defp map_integration_type(integration_type),
    do:
      integration_type
      |> String.upcase()
      |> String.to_atom()
      |> InternalApi.RepositoryIntegrator.IntegrationType.value()

  @spec file_exists?(String.t(), String.t()) :: boolean
  def file_exists?(project_id, path) do
    alias InternalApi.RepositoryIntegrator.GetFileRequest
    alias InternalApi.RepositoryIntegrator.RepositoryIntegratorService.Stub

    req = GetFileRequest.new(project_id: project_id, path: path)

    {:ok, ch} =
      GRPC.Stub.connect(Application.fetch_env!(:front, :repository_integrator_grpc_endpoint))

    case Stub.get_file(ch, req, options()) do
      {:ok, _} ->
        true

      {:error, error} ->
        Logger.error(
          "Looking for a file #{path} in project #{project_id} failed: #{inspect(error)}"
        )

        false
    end
  end

  def destroy(project_id, user_id, org_id, metadata \\ nil) do
    alias InternalApi.ResponseStatus.Code

    Watchman.benchmark("destroy_project.duration", fn ->
      with true <- Front.Auth.delete_project?(user_id, project_id, org_id, metadata),
           req_meta <- RequestMeta.new(org_id: org_id, user_id: user_id),
           request <- DestroyRequest.new(metadata: req_meta, id: project_id),
           {:ok, response} <- Stub.destroy(channel(), request, options()),
           :OK <- Code.key(response.metadata.status.code) do
        Logger.info("Project deleted: p: #{project_id}, u: #{user_id}; o: #{org_id}")

        {:ok, response}
      else
        false ->
          {:error, "not-authorized"}

        e ->
          Logger.info("Project deletion failed: #{project_id}, #{user_id}; #{inspect(e)}")
          Watchman.increment("project.destroy.failed")

          {:error, :grpc_req_failed}
      end
    end)
  end

  def update(project_data, user_id, org_id, metadata \\ nil) do
    alias InternalApi.Projecthub.Project, as: ProjectReq
    alias InternalApi.Projecthub.ResponseMeta.Code

    Watchman.benchmark("update-project.duration", fn ->
      allowed_contributors = extract_allowed_contributors(project_data)
      allowed_secrets = extract_allowed_secrets(project_data)
      branches = extract_branches(project_data)
      tags = extract_tags(project_data)
      visibility = extract_visibility(project_data)
      run_on = extract_run_on(project_data)
      debug_permissions = extract_debug_permissions(project_data)
      attach_permissions = extract_attach_permissions(project_data)
      run = run_on |> Enum.any?()

      project_update =
        ProjectReq.new(
          metadata:
            Metadata.new(
              id: project_data.id,
              name: project_data.name,
              description: project_data.description
            ),
          spec:
            Spec.new(
              repository:
                Repository.new(
                  url: project_data.repo_url,
                  run_on: run_on,
                  run_present: {:run, run},
                  forked_pull_requests:
                    ForkedPullRequests.new(
                      allowed_secrets: allowed_secrets,
                      allowed_contributors: allowed_contributors
                    ),
                  status: project_data.commit_status,
                  pipeline_file: project_data.initial_pipeline_file,
                  whitelist:
                    Whitelist.new(
                      branches: branches,
                      tags: tags
                    )
                ),
              visibility: visibility,
              custom_permissions: project_data.custom_permissions,
              debug_permissions: debug_permissions,
              attach_permissions: attach_permissions
            )
        )

      with true <- Front.Auth.update_project?(user_id, project_data.id, org_id, metadata),
           req_meta <- RequestMeta.new(org_id: org_id, user_id: user_id),
           request <-
             UpdateRequest.new(
               metadata: req_meta,
               project: project_update,
               omit_schedulers_and_tasks: true
             ),
           {:ok, response} <- Stub.update(channel(), request, options()),
           {:OK, _} <- {Code.key(response.metadata.status.code), response.metadata.status.message} do
        Logger.info("Project updated: p: #{project_data.id}, u: #{user_id};")

        {:ok, response}
      else
        false ->
          {:error, "not-authorized"}

        {:FAILED_PRECONDITION, message} ->
          Logger.info("Project update failed: #{project_data.id}, #{user_id}; #{message}")
          Watchman.increment("project.update.failed")

          {:error, :message, message}

        e ->
          Logger.info("Project update failed: #{project_data.id}, #{user_id}; #{inspect(e)}")
          Watchman.increment("project.update.failed")

          {:error, :grpc_req_failed}
      end
    end)
  end

  def change_owner(org_id, project_id, owner_id, user_id) do
    req_meta = RequestMeta.new(org_id: org_id, user_id: user_id)

    request =
      InternalApi.Projecthub.ChangeProjectOwnerRequest.new(
        metadata: req_meta,
        id: project_id,
        user_id: owner_id
      )

    {:ok, res} = Stub.change_project_owner(channel(), request, options())

    case InternalApi.Projecthub.ResponseMeta.Code.key(res.metadata.status.code) do
      :OK -> {:ok, nil}
      _ -> {:error, res.metadata.status.message}
    end
  end

  def list(org_id, user_id, _page \\ 1, _metadata \\ nil, _trace_id \\ "") do
    Watchman.benchmark("list_projects.duration", fn ->
      {projects, total_pages} = list_(org_id, user_id)

      readable_projects = projects |> Front.RBAC.Members.filter_projects(org_id, user_id)

      {readable_projects, total_pages}
    end)
  end

  def list_(org_id, user_id, page \\ 1, projects \\ []) do
    req = InternalApi.Projecthub.RequestMeta.new(org_id: org_id)
    pagination = InternalApi.Projecthub.PaginationRequest.new(page: page, page_size: 300)

    list_request =
      InternalApi.Projecthub.ListRequest.new(
        metadata: req,
        pagination: pagination
      )

    {:ok, res} =
      InternalApi.Projecthub.ProjectService.Stub.list(
        channel(),
        list_request,
        options()
      )

    more_projects = construct_list(res.projects)

    total_pages = res.pagination.total_pages

    if page < total_pages do
      list_(org_id, user_id, page + 1, projects ++ more_projects)
    else
      {projects ++ more_projects, total_pages}
    end
  end

  def list_all(org_id) do
    response_by_params(org_id)
    |> extract_projects_list
  end

  def list_by_owner(org_id, owner_id) do
    response_by_params(org_id, owner_id: owner_id)
    |> extract_projects_list
  end

  def list_by_repo_url(org_id, repo_url) do
    response_by_params(org_id, repo_url: repo_url)
    |> extract_projects_list
  end

  def count(org_id) do
    response_by_params(org_id, [], 1)
    |> extract_projects_count
  end

  def count_by_owner(org_id, owner_id) do
    response_by_params(org_id, [owner_id: owner_id], 1)
    |> extract_projects_count
  end

  defp response_by_params(org_id, params \\ [], page_size \\ 300) do
    req = InternalApi.Projecthub.RequestMeta.new(org_id: org_id)
    pagination = InternalApi.Projecthub.PaginationRequest.new(page: 1, page_size: page_size)

    defaults = [
      owner_id: "",
      repo_url: ""
    ]

    params = Keyword.merge(defaults, params)

    list_request =
      InternalApi.Projecthub.ListRequest.new(
        metadata: req,
        pagination: pagination,
        owner_id: params[:owner_id],
        repo_url: params[:repo_url]
      )

    {:ok, res} =
      InternalApi.Projecthub.ProjectService.Stub.list(
        channel(),
        list_request,
        options()
      )

    if res.metadata.status.code == InternalApi.ResponseStatus.Code.value(:OK) do
      {:ok, res}
    else
      {:error, nil}
    end
  end

  defp extract_projects_list({:ok, res}), do: {:ok, construct_list(res.projects)}
  defp extract_projects_list(error), do: error

  defp extract_projects_count({:ok, res}), do: {:ok, res.pagination.total_entries}
  defp extract_projects_count(error), do: error

  def project_name_cache_key(project_id), do: "project-name-#{project_id}"

  def project_name(project_id) do
    Watchman.benchmark("fetch_project_name.duration", fn ->
      project_name_cache_key(project_id)
      |> Front.Cache.get()
      |> case do
        {:ok, ""} -> {project_id, nil}
        {:ok, project_name} -> {project_id, project_name}
        {:not_cached, _} -> {project_id, nil}
      end
      |> case do
        {project_id, nil} ->
          find_by_id(project_id)
          |> case do
            {:ok, project} -> project.name
            _ -> ""
          end

        {_project_id, project_name} ->
          project_name
      end
    end)
  end

  def project_names(project_ids) do
    project_ids
    |> Enum.map(fn project_id ->
      project_name_cache_key(project_id)
      |> Front.Cache.get()
      |> case do
        {:ok, ""} -> {project_id, nil}
        {:ok, project_name} -> {project_id, project_name}
        {:not_cached, _} -> {project_id, nil}
      end
    end)
    |> Enum.split_with(fn
      {_project_id, nil} -> true
      {_project_id, _project_name} -> false
    end)
    |> then(fn {not_cached_entries, found_entries} ->
      missing_entries =
        not_cached_entries
        |> Enum.map(fn {project_id, _project_name} -> project_id end)
        |> find_many_by_ids()
        |> Enum.map(fn project ->
          project_name_cache_key(project.id)
          |> Front.Cache.set(project.name, @project_name_cache_ttl)

          {project.id, project.name}
        end)

      found_entries ++ missing_entries
    end)
  end

  def finish_onboarding(project_id) do
    Watchman.benchmark("projecthub.finish_onboarding.duration", fn ->
      req =
        InternalApi.Projecthub.FinishOnboardingRequest.new(
          metadata: InternalApi.Projecthub.RequestMeta.new(),
          id: project_id
        )

      Stub.finish_onboarding(channel(), req, options())
      |> case do
        {:ok, %{metadata: %{status: %{code: 0}}}} -> {:ok, nil}
        {:ok, res} -> {:error, res.metadata.status.message}
        _ -> {:error, ""}
      end
    end)
  end

  def github_switch(project_id) do
    Watchman.benchmark("projecthub.github_switch.duration", fn ->
      req =
        InternalApi.Projecthub.GithubAppSwitchRequest.new(
          metadata: InternalApi.Projecthub.RequestMeta.new(),
          id: project_id
        )

      case InternalApi.Projecthub.ProjectService.Stub.github_app_switch(channel(), req, options()) do
        {:ok, %{metadata: %{status: %{code: 0}}}} ->
          {:ok, nil}

        {:ok, res} ->
          {:error, res.metadata.status.message}

        _ ->
          {:error, ""}
      end
    end)
  end

  def github_installation_info(project_id) do
    Watchman.benchmark("projecthub.github_installation_info.duration", fn ->
      req =
        InternalApi.RepositoryIntegrator.GithubInstallationInfoRequest.new(project_id: project_id)

      {:ok, channel} =
        GRPC.Stub.connect(Application.fetch_env!(:front, :repository_integrator_grpc_endpoint))

      case InternalApi.RepositoryIntegrator.RepositoryIntegratorService.Stub.github_installation_info(
             channel,
             req,
             timeout: 30_000
           ) do
        {:ok, res} ->
          installation = %{
            installation_id: res.installation_id,
            application_url: res.application_url,
            installation_url: res.installation_url,
            setup_url: "#{res.application_url}/installations/new"
          }

          {:ok, installation}

        _ ->
          {:error, ""}
      end
    end)
  end

  def check_token(project_id) do
    Watchman.benchmark("projecthub.check_token.duration", fn ->
      req = InternalApi.RepositoryIntegrator.CheckTokenRequest.new(project_id: project_id)

      {:ok, channel} =
        GRPC.Stub.connect(Application.fetch_env!(:front, :repository_integrator_grpc_endpoint))

      case InternalApi.RepositoryIntegrator.RepositoryIntegratorService.Stub.check_token(
             channel,
             req,
             timeout: 30_000
           ) do
        {:ok, res} ->
          scope = InternalApi.RepositoryIntegrator.IntegrationScope.key(res.integration_scope)

          {:ok, %{valid: res.valid, scope: scope}}

        _ ->
          {:error, ""}
      end
    end)
  end

  def check_webhook(project_id) do
    Watchman.benchmark("projecthub.check_webhook.duration", fn ->
      req =
        InternalApi.Projecthub.CheckWebhookRequest.new(
          metadata: InternalApi.Projecthub.RequestMeta.new(),
          id: project_id
        )

      {:ok, res} =
        InternalApi.Projecthub.ProjectService.Stub.check_webhook(channel(), req, options())

      case InternalApi.Projecthub.ResponseMeta.Code.key(res.metadata.status.code) do
        :OK ->
          hook = %{
            url: res.webhook.url
          }

          {:ok, hook}

        _ ->
          {:error, res.metadata.status.message}
      end
    end)
  end

  def regenerate_webhook(project_id) do
    Watchman.benchmark("projecthub.regenerate_webhook.duration", fn ->
      req =
        InternalApi.Projecthub.RegenerateWebhookRequest.new(
          metadata: InternalApi.Projecthub.RequestMeta.new(),
          id: project_id
        )

      {:ok, res} =
        InternalApi.Projecthub.ProjectService.Stub.regenerate_webhook(
          channel(),
          req,
          options()
        )

      case InternalApi.Projecthub.ResponseMeta.Code.key(res.metadata.status.code) do
        :OK ->
          hook = %{
            url: res.webhook.url
          }

          {:ok, hook}

        _ ->
          {:error, res.metadata.status.message}
      end
    end)
  end

  def check_deploy_key(project_id) do
    Watchman.benchmark("projecthub.check_deploy_key.duration", fn ->
      req =
        InternalApi.Projecthub.CheckDeployKeyRequest.new(
          metadata: InternalApi.Projecthub.RequestMeta.new(),
          id: project_id
        )

      {:ok, res} =
        InternalApi.Projecthub.ProjectService.Stub.check_deploy_key(channel(), req, options())

      case InternalApi.Projecthub.ResponseMeta.Code.key(res.metadata.status.code) do
        :OK ->
          key = %{
            title: res.deploy_key.title,
            fingerprint: res.deploy_key.fingerprint,
            created_at: Front.Utils.decorate_date(res.deploy_key.created_at.seconds),
            public_key: res.deploy_key.public_key
          }

          {:ok, key}

        _ ->
          {:error, res.metadata.status.message}
      end
    end)
  end

  def regenerate_deploy_key(project_id) do
    Watchman.benchmark("projecthub.regenerate_deploy_key.duration", fn ->
      req =
        InternalApi.Projecthub.RegenerateDeployKeyRequest.new(
          metadata: InternalApi.Projecthub.RequestMeta.new(),
          id: project_id
        )

      {:ok, res} =
        InternalApi.Projecthub.ProjectService.Stub.regenerate_deploy_key(
          channel(),
          req,
          options()
        )

      case InternalApi.Projecthub.ResponseMeta.Code.key(res.metadata.status.code) do
        :OK ->
          key = %{
            title: res.deploy_key.title,
            fingerprint: res.deploy_key.fingerprint,
            created_at: Front.Utils.decorate_date(res.deploy_key.created_at.seconds),
            public_key: res.deploy_key.public_key
          }

          {:ok, key}

        _ ->
          {:error, res.metadata.status.message}
      end
    end)
  end

  defp construct(project) do
    alias InternalApi.Projecthub.Project.Spec.Repository.RunType
    alias InternalApi.Projecthub.Project.Spec.Visibility
    alias InternalApi.Projecthub.Project.Status.State
    alias InternalApi.RepositoryIntegrator.IntegrationType

    allowed_secrets =
      case project.spec.repository.forked_pull_requests do
        nil -> ""
        options -> options.allowed_secrets |> Enum.join(", ")
      end

    allowed_contributors =
      case project.spec.repository.forked_pull_requests do
        nil -> ""
        options -> options.allowed_contributors |> Enum.join(", ")
      end

    {branch_whitelist, tag_whitelist} =
      case project.spec.repository.whitelist do
        nil ->
          {"", ""}

        whitelist ->
          {whitelist.branches |> Enum.join(", "), whitelist.tags |> Enum.join(", ")}
      end

    %__MODULE__{
      :id => project.metadata.id,
      :name => project.metadata.name,
      :owner_id => project.metadata.owner_id,
      :organization_id => project.metadata.org_id,
      :description => project.metadata.description,
      :created_at => Timex.from_unix(project.metadata.created_at.seconds),
      :repo_owner => project.spec.repository.owner,
      :repo_name => project.spec.repository.name,
      :repo_url => project.spec.repository.url,
      :repo_public => project.spec.repository.public,
      :repo_default_branch => project.spec.repository.default_branch,
      :run => !Enum.empty?(project.spec.repository.run_on),
      :build_branches => project.spec.repository.run_on |> Enum.member?(RunType.value(:BRANCHES)),
      :whitelist_branches => branch_whitelist != "",
      :branch_whitelist => branch_whitelist,
      :build_tags => project.spec.repository.run_on |> Enum.member?(RunType.value(:TAGS)),
      :whitelist_tags => tag_whitelist != "",
      :tag_whitelist => tag_whitelist,
      :build_prs => project.spec.repository.run_on |> Enum.member?(RunType.value(:PULL_REQUESTS)),
      :build_forked_prs =>
        project.spec.repository.run_on |> Enum.member?(RunType.value(:FORKED_PULL_REQUESTS)),
      :build_draft_prs =>
        project.spec.repository.run_on |> Enum.member?(RunType.value(:DRAFT_PULL_REQUESTS)),
      :custom_permissions => project.spec.custom_permissions,
      :allow_debug_empty_session =>
        project.spec.debug_permissions |> Enum.member?(PermissionType.value(:EMPTY)),
      :allow_debug_default_branch =>
        project.spec.debug_permissions |> Enum.member?(PermissionType.value(:DEFAULT_BRANCH)),
      :allow_debug_non_default_branch =>
        project.spec.debug_permissions |> Enum.member?(PermissionType.value(:NON_DEFAULT_BRANCH)),
      :allow_debug_pr =>
        project.spec.debug_permissions |> Enum.member?(PermissionType.value(:PULL_REQUEST)),
      :allow_debug_forked_pr =>
        project.spec.debug_permissions |> Enum.member?(PermissionType.value(:FORKED_PULL_REQUEST)),
      :allow_debug_tag =>
        project.spec.debug_permissions |> Enum.member?(PermissionType.value(:TAG)),
      :allow_attach_default_branch =>
        project.spec.attach_permissions |> Enum.member?(PermissionType.value(:DEFAULT_BRANCH)),
      :allow_attach_non_default_branch =>
        project.spec.attach_permissions |> Enum.member?(PermissionType.value(:NON_DEFAULT_BRANCH)),
      :allow_attach_pr =>
        project.spec.attach_permissions |> Enum.member?(PermissionType.value(:PULL_REQUEST)),
      :allow_attach_forked_pr =>
        project.spec.attach_permissions
        |> Enum.member?(PermissionType.value(:FORKED_PULL_REQUEST)),
      :allow_attach_tag =>
        project.spec.attach_permissions |> Enum.member?(PermissionType.value(:TAG)),
      :expose_secrets => allowed_secrets != "",
      :allowed_secrets => allowed_secrets,
      :filter_contributors => allowed_contributors != "",
      :allowed_contributors => allowed_contributors,
      :initial_pipeline_file => project.spec.repository.pipeline_file,
      :public => project.spec.visibility == Visibility.value(:PUBLIC),
      :state => State.key(project.status.state),
      :state_reason => project.status.state_reason,
      :cache_state => State.key(project.status.cache.state),
      :artifact_store_state => State.key(project.status.artifact_store.state),
      :repository_state => State.key(project.status.repository.state),
      :permissions_state => State.key(project.status.permissions.state),
      :analysis_state => State.key(project.status.analysis.state),
      :integration_type => IntegrationType.key(project.spec.repository.integration_type),
      :commit_status => project.spec.repository.status,
      :repo_connected => project.spec.repository.connected,
      :repo_id => project.spec.repository.id,
      :cache_id => project.spec.cache_id,
      :artifact_store_id => project.spec.artifact_store_id
    }
  end

  def find_by_id(id, org_id \\ "")

  def find_by_id(nil, _org_id), do: nil

  def find_by_id(id, org_id) do
    Watchman.benchmark("projecthub.find_by_id.duration", fn ->
      req =
        InternalApi.Projecthub.DescribeRequest.new(
          metadata: InternalApi.Projecthub.RequestMeta.new(org_id: org_id),
          id: id
        )

      describe_request(req)
    end)
  end

  def find_many_by_ids(project_ids, org_id \\ "") do
    Watchman.benchmark("projecthub.find_many_by_id.duration", fn ->
      {:ok, stream_supervisor} = Task.Supervisor.start_link()

      stream_supervisor
      |> Task.Supervisor.async_stream(
        project_ids,
        fn project_id ->
          request =
            InternalApi.Projecthub.DescribeRequest.new(
              id: project_id,
              metadata: InternalApi.Projecthub.RequestMeta.new(org_id: org_id)
            )

          describe_request(request)
        end,
        ordered: false,
        max_concurrency: 5,
        timeout: :timer.seconds(10)
      )
      |> Enum.map(fn {:ok, project} -> project end)
      |> Enum.filter(& &1)
    end)
  end

  defp find_by_name(nil, _org_id), do: nil

  defp find_by_name(name, org_id) do
    Watchman.benchmark("projecthub.find_by_name.duration", fn ->
      req =
        InternalApi.Projecthub.DescribeRequest.new(
          metadata: InternalApi.Projecthub.RequestMeta.new(org_id: org_id),
          name: name
        )

      describe_request(req)
    end)
  end

  defp describe_request(req) do
    {:ok, res} = InternalApi.Projecthub.ProjectService.Stub.describe(channel(), req, options())

    case InternalApi.Projecthub.ResponseMeta.Code.key(res.metadata.status.code) do
      :OK -> construct(res.project)
      :NOT_FOUND -> nil
    end
  end

  defp construct_list(raw_projects) do
    Watchman.benchmark("list_projects.construct_list.duration", fn ->
      raw_projects
      |> Enum.map(fn project ->
        %__MODULE__{
          :name => project.metadata.name,
          :id => project.metadata.id,
          :description => project.metadata.description
        }
      end)
    end)
  end

  defp channel do
    Watchman.benchmark("projecthub.connect.duration", fn ->
      {:ok, ch} = GRPC.Stub.connect(Application.fetch_env!(:front, :projecthub_grpc_endpoint))

      ch
    end)
  end

  defp options, do: [timeout: 30_000]

  defp validate_branch_whitelists(changeset) do
    cond do
      get_field(changeset, :run) == false ->
        changeset

      get_field(changeset, :build_branches) == false ->
        changeset

      get_field(changeset, :whitelist_branches) == false ->
        changeset

      get_field(changeset, :branch_whitelist) == nil ->
        add_error(changeset, :branch_whitelist, "Please specify at least one branch")

      true ->
        changeset
    end
  end

  defp validate_tag_whitelists(changeset) do
    cond do
      get_field(changeset, :run) == false ->
        changeset

      get_field(changeset, :build_tags) == false ->
        changeset

      get_field(changeset, :whitelist_tags) == false ->
        changeset

      get_field(changeset, :tag_whitelist) == nil ->
        add_error(changeset, :tag_whitelist, "Please specify at least one tag")

      true ->
        changeset
    end
  end

  defp validate_exposed_secrets(changeset) do
    cond do
      get_field(changeset, :run) == false ->
        changeset

      get_field(changeset, :build_forked_prs) == false ->
        changeset

      get_field(changeset, :expose_secrets) == false ->
        changeset

      get_field(changeset, :allowed_secrets) == nil ->
        add_error(changeset, :allowed_secrets, "Please specify at least one secret")

      get_field(changeset, :allowed_secrets) |> invalid_secrets? ->
        add_error(
          changeset,
          :allowed_secrets,
          "Secrets names must only contain [a-z], [A-Z] or [0-9] characters, hyphens and underscores"
        )

      true ->
        changeset
    end
  end

  defp validate_contributors(changeset) do
    cond do
      get_field(changeset, :run) == false ->
        changeset

      get_field(changeset, :build_forked_prs) == false ->
        changeset

      get_field(changeset, :filter_contributors) == false ->
        changeset

      get_field(changeset, :allowed_contributors) == nil ->
        add_error(
          changeset,
          :allowed_contributors,
          "Please specify at least one contributor's login"
        )

      get_field(changeset, :allowed_contributors) |> invalid_contributors? ->
        add_error(
          changeset,
          :allowed_contributors,
          "Contributor's logins must only contain [a-z], [A-Z] or [0-9] characters, and hyphens"
        )

      true ->
        changeset
    end
  end

  defp invalid_secrets?(secrets), do: !valid_secrets?(secrets)

  defp valid_secrets?(secrets) do
    secrets
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.all?(fn s -> String.match?(s, ~r/^[a-zA-Z0-9-_]+$/) end)
  end

  defp invalid_contributors?(contributors), do: !valid_contributors(contributors)

  defp valid_contributors(contributors) do
    contributors
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.all?(fn s -> String.match?(s, ~r/^[a-zA-Z0-9-]+$/) end)
  end

  defp validate_run_on_table(changeset) do
    case get_field(changeset, :run) do
      true ->
        if get_field(changeset, :build_branches) || get_field(changeset, :build_tags) ||
             get_field(changeset, :build_prs) || get_field(changeset, :build_forked_prs) do
          changeset
        else
          add_error(changeset, :run_on, "One of the triggers must be selected")
        end

      false ->
        changeset
    end
  end

  defp validate_commit_status(changeset) do
    if get_change(changeset, :initial_pipeline_file),
      do: put_change(changeset, :commit_status, nil),
      else: changeset
  end

  defp split_and_trim(list) do
    list
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
  end

  defp extract_allowed_contributors(data) do
    if data.run && data.build_forked_prs && data.filter_contributors do
      data.allowed_contributors |> split_and_trim()
    else
      []
    end
  end

  defp extract_allowed_secrets(data) do
    if data.run && data.build_forked_prs && data.expose_secrets do
      data.allowed_secrets |> split_and_trim()
    else
      []
    end
  end

  defp extract_branches(data) do
    if data.run && data.build_branches && data.whitelist_branches do
      data.branch_whitelist |> Front.Utils.regexp_split()
    else
      []
    end
  end

  defp extract_tags(data) do
    if data.run && data.build_tags && data.whitelist_tags do
      data.tag_whitelist |> Front.Utils.regexp_split()
    else
      []
    end
  end

  defp extract_visibility(data) do
    alias InternalApi.Projecthub.Project.Spec.Visibility

    if data.public do
      Visibility.value(:PUBLIC)
    else
      Visibility.value(:PRIVATE)
    end
  end

  defp extract_run_on(data) do
    if data.run do
      [
        {:TAGS, data.build_tags},
        {:BRANCHES, data.build_branches},
        {:PULL_REQUESTS, data.build_prs},
        {:FORKED_PULL_REQUESTS, data.build_forked_prs},
        {:DRAFT_PULL_REQUESTS, data.build_draft_prs}
      ]
      |> Enum.filter(fn e -> elem(e, 1) end)
      |> Enum.map(fn e -> elem(e, 0) end)
      |> Enum.map(fn e -> InternalApi.Projecthub.Project.Spec.Repository.RunType.value(e) end)
    else
      []
    end
  end

  defp extract_debug_permissions(%{custom_permissions: false}), do: []

  defp extract_debug_permissions(data) do
    [
      {:DEFAULT_BRANCH, data.allow_debug_default_branch},
      {:NON_DEFAULT_BRANCH, data.allow_debug_non_default_branch},
      {:PULL_REQUEST, data.allow_debug_pr},
      {:FORKED_PULL_REQUEST, data.allow_debug_forked_pr},
      {:TAG, data.allow_debug_tag},
      {:EMPTY, data.allow_debug_empty_session}
    ]
    |> Enum.filter(fn e -> elem(e, 1) end)
    |> Enum.map(fn e -> elem(e, 0) end)
    |> Enum.map(fn e -> PermissionType.value(e) end)
  end

  defp extract_attach_permissions(%{custom_permissions: false}), do: []

  defp extract_attach_permissions(data) do
    [
      {:DEFAULT_BRANCH, data.allow_attach_default_branch},
      {:NON_DEFAULT_BRANCH, data.allow_attach_non_default_branch},
      {:PULL_REQUEST, data.allow_attach_pr},
      {:FORKED_PULL_REQUEST, data.allow_attach_forked_pr},
      {:TAG, data.allow_attach_tag}
    ]
    |> Enum.filter(fn e -> elem(e, 1) end)
    |> Enum.map(fn e -> elem(e, 0) end)
    |> Enum.map(fn e -> PermissionType.value(e) end)
  end
end
