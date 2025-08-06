defmodule Projecthub.Api.GrpcServer do
  import Toolkit
  require Logger
  use GRPC.Server, service: InternalApi.Projecthub.ProjectService.Service

  if Application.fetch_env!(:projecthub, :environment) == :prod do
    use Sentry.Grpc, service: InternalApi.Projecthub.ProjectService.Service
  end

  alias Projecthub.RepositoryHubClient
  alias Projecthub.TaskSupervisor
  alias Projecthub.Models
  alias Projecthub.Models.Project
  alias Projecthub.Models.User
  alias Projecthub.Models.Organization
  alias Projecthub.Models.Scheduler
  alias Projecthub.Models.PeriodicTask
  alias InternalApi.Projecthub.DescribeResponse
  alias InternalApi.Projecthub.DescribeManyResponse
  alias InternalApi.Projecthub.ListResponse
  alias InternalApi.Projecthub.ListKeysetResponse
  alias InternalApi.Projecthub.DestroyResponse
  alias InternalApi.Projecthub.RestoreResponse
  alias InternalApi.Projecthub.CreateResponse
  alias InternalApi.Projecthub.ForkAndCreateResponse
  alias InternalApi.Projecthub.UpdateResponse
  alias InternalApi.Projecthub.UsersResponse
  alias InternalApi.Projecthub.CheckDeployKeyResponse
  alias InternalApi.Projecthub.RegenerateDeployKeyResponse
  alias InternalApi.Projecthub.CheckWebhookResponse
  alias InternalApi.Projecthub.RegenerateWebhookResponse
  alias InternalApi.Projecthub.RegenerateWebhookSecretResponse
  alias InternalApi.Projecthub.ChangeProjectOwnerResponse
  alias InternalApi.Projecthub.GithubAppSwitchResponse
  alias InternalApi.Projecthub.FinishOnboardingResponse
  alias InternalApi.Projecthub.Webhook
  alias InternalApi.Projecthub.Project.Spec.Visibility
  alias InternalApi.Projecthub.Project.Spec.Repository

  def describe(request, _) do
    Watchman.benchmark("projecthub_api.describe.duration", fn ->
      find_project(request, request.soft_deleted)
      |> case do
        {:ok, project} ->
          DescribeResponse.new(
            metadata: status_ok(request),
            project: serialize(project, request.detailed)
          )

        _ ->
          DescribeResponse.new(metadata: status_not_found(request))
      end
    end)
  end

  def describe_many(req, _) do
    Watchman.benchmark("projecthub_api.describe_many.duration", fn ->
      projects = Project.find_many(req.metadata.org_id, req.ids, req.soft_deleted)

      projects =
        projects
        |> Task.async_stream(
          fn project ->
            {:ok, repository} = Models.Repository.find_for_project(project.id)
            %{project | repository: repository}
          end,
          ordered: false,
          max_concurrency: 3
        )
        |> Enum.map(fn result ->
          {:ok, project} = result
          project
        end)

      DescribeManyResponse.new(
        metadata: status_ok(req),
        projects: Enum.map(projects, fn p -> serialize(p, false) end)
      )
    end)
  end

  def list(req, _) do
    Watchman.benchmark("projecthub_api.list.duration", fn ->
      with {:ok, url} <- validate_repo_url(req.repo_url),
           projects <- list_projects(req, url) do
        Watchman.benchmark("projecthub_api.construct_list_response.duration", fn ->
          ListResponse.new(
            metadata: status_ok(req),
            pagination:
              InternalApi.Projecthub.PaginationResponse.new(
                page_number: projects.page_number,
                page_size: projects.page_size,
                total_entries: projects.total_entries,
                total_pages: projects.total_pages
              ),
            projects: Enum.map(projects.entries, fn p -> serialize(p, false) end)
          )
        end)
      else
        {:error, messages} ->
          ListResponse.new(metadata: status_failed_precondition(req, messages))
      end
    end)
  end

  def list_keyset(req, _) do
    Watchman.benchmark("projecthub_api.list_keyset.duration", fn ->
      with {:ok, url} <- validate_repo_url(req.repo_url),
           projects <- paginated_list(req, url) do
        Watchman.benchmark("projecthub_api.construct_list_response.duration", fn ->
          ListKeysetResponse.new(
            metadata: status_ok(req),
            projects: Enum.map(projects.entries, fn p -> serialize(p, false) end),
            next_page_token: projects.metadata.after,
            previous_page_token: projects.metadata.before
          )
        end)
      else
        {:error, messages} ->
          ListKeysetResponse.new(metadata: status_failed_precondition(req, messages))
      end
    end)
  end

  defp list_projects(req, url) do
    Watchman.benchmark("projecthub.list_per_page.duration", fn ->
      Project.list_per_page(
        req.metadata.org_id,
        req.pagination.page,
        req.pagination.page_size,
        owner_id: req.owner_id,
        repo_url: url,
        soft_deleted: req.soft_deleted
      )
    end)
  end

  defp paginated_list(req, url) do
    Watchman.benchmark("projecthub.paginated_list.duration", fn ->
      Project.list_per_page_with_cursor(
        req.metadata.org_id,
        req.page_token,
        req.direction,
        req.page_size,
        owner_id: req.owner_id,
        repo_url: url,
        created_after: timestamp_to_datetime(req.created_after)
      )
    end)
  end

  defp validate_repo_url(url)
       when is_binary(url) and url != "" do
    case Projecthub.RepoUrl.validate(url) do
      {:ok, parts} ->
        {:ok, parts.ssh_git_url}

      error ->
        error
    end
  end

  defp validate_repo_url(_), do: {:ok, nil}

  def fork_and_create(req, _) do
    Watchman.benchmark("projecthub_api.fork_and_create.duration", fn ->
      alias Projecthub.ParamsChecker

      fetch_user =
        Task.Supervisor.async_nolink(
          TaskSupervisor,
          fn -> find_user(req) end
        )

      fetch_org =
        Task.Supervisor.async_nolink(
          TaskSupervisor,
          fn -> find_org(req) end
        )

      project_metadata = req.project.metadata
      repo = req.project.spec.repository
      project_spec = req.project.spec

      integration_type =
        repo.integration_type
        |> Atom.to_string()
        |> String.downcase()

      with {:ok, user} <- Task.yield(fetch_user),
           {:ok, org} <- Task.yield(fetch_org),
           {:ok, response} <-
             RepositoryHubClient.fork(%{
               user_id: user.id,
               url: req.project.spec.repository.url,
               integration_type: req.project.spec.repository.integration_type
             }),
           url <- response.remote_repository.url,
           repo <- %{repo | url: url},
           {:ok, project} <-
             attempt_creation(
               user,
               org,
               project_metadata,
               project_spec,
               repo,
               req,
               integration_type,
               true
             ) do
        Logger.info("ForkAndCreate finished successfully. Request: #{inspect(req)}")

        Watchman.increment({"repository.integration_type", ["#{integration_type}"]})

        ForkAndCreateResponse.new(
          metadata: status_ok(req),
          project: serialize(project)
        )
      else
        {:error, messages} when is_list(messages) ->
          Logger.info("ForkAndCreate failed. Error: #{messages |> Enum.join(", ")} Request: #{inspect(req)}")

          error_create_response(req, messages |> Enum.join(", "))

        {:error, %{message: message}} ->
          error_create_response(req, message)

        {:error, message} ->
          Logger.info("ForkAndCreate failed. Error: #{message} Request: #{inspect(req)}")
          error_create_response(req, message)

        error ->
          Logger.info("ForkAndCreate failed. Error: #{error} Request: #{inspect(req)}")
          error_create_response(req, "Something went wrong. Please try again.")
      end
    end)
  end

  def create(req, _) do
    Watchman.benchmark("projecthub_api.create.duration", fn ->
      alias Projecthub.ParamsChecker

      fetch_user =
        Task.Supervisor.async_nolink(
          TaskSupervisor,
          fn -> find_user(req) end
        )

      fetch_org =
        Task.Supervisor.async_nolink(
          TaskSupervisor,
          fn -> find_org(req) end
        )

      repo = req.project.spec.repository
      project_metadata = req.project.metadata
      project_spec = req.project.spec

      integration_type =
        repo.integration_type
        |> Atom.to_string()
        |> String.downcase()

      with {:ok, user} <- Task.yield(fetch_user),
           {:ok, org} <- Task.yield(fetch_org),
           {:ok, project} <-
             attempt_creation(
               user,
               org,
               project_metadata,
               project_spec,
               repo,
               req,
               integration_type,
               req.skip_onboarding
             ) do
        Logger.info("Create finished successfully. Request: #{inspect(req)}")

        CreateResponse.new(
          metadata: status_ok(req),
          project: serialize(project)
        )
      else
        {:error, messages} when is_list(messages) ->
          error_create_response(req, messages |> Enum.join(", "))

        {:error, %{message: message}} ->
          error_create_response(req, message)

        {:error, message} ->
          error_create_response(req, message)

        _ ->
          error_create_response(req, "Something went wrong. Please try again.")
      end
    end)
  end

  defp error_create_response(req, message) do
    CreateResponse.new(metadata: status_failed_precondition(req, message))
  end

  def update(req, _) do
    Watchman.benchmark("projecthub_api.update.duration", fn ->
      alias Projecthub.ParamsChecker

      project_id = req.project.metadata.id
      project_metadata = req.project.metadata
      project_spec = req.project.spec

      with org <- find_org(req),
           {:ok, project} <- Project.find(project_id),
           :ok <- ParamsChecker.run(project_spec, org.open_source) do
        attempt_update(project, project_metadata, project_spec, req)
      else
        {:error, :not_found} ->
          UpdateResponse.new(metadata: status_not_found(req, project_id))

        {:error, %{message: message}} ->
          UpdateResponse.new(metadata: status_failed_precondition(req, message))

        {:error, messages} ->
          UpdateResponse.new(
            metadata:
              status_failed_precondition(
                req,
                Enum.join(messages, ", ")
              )
          )

        _ ->
          UpdateResponse.new(metadata: status_failed_precondition(req, ""))
      end
    end)
  end

  def destroy(req, _) do
    Watchman.benchmark("projecthub_api.destroy.duration", fn ->
      user = find_user(req)

      if user do
        case find_project(req) do
          {:ok, project} ->
            {:ok, _} = Project.soft_destroy(project, user)
            DestroyResponse.new(metadata: status_ok(req))

          {:error, :not_found} ->
            DestroyResponse.new(metadata: status_not_found(req))

          {:error, %{message: message}} ->
            DestroyResponse.new(metadata: status_failed_precondition(req, message))
        end
      end
    end)
  end

  def restore(req, _) do
    Watchman.benchmark("projecthub_api.restore.duration", fn ->
      soft_deleted = true

      case find_project(req, soft_deleted) do
        {:ok, project} ->
          {:ok, _} = Project.restore(project)
          RestoreResponse.new(metadata: status_ok(req))

        {:error, :not_found} ->
          RestoreResponse.new(metadata: status_not_found(req))

        {:error, %{message: message}} ->
          RestoreResponse.new(metadata: status_failed_precondition(req, message))
      end
    end)
  end

  # DEPRECATED
  def users(req, _) do
    Watchman.benchmark("projecthub_api.users.duration", fn ->
      UsersResponse.new(
        metadata: status_ok(req),
        users: []
      )
    end)
  end

  def check_deploy_key(req, _) do
    Watchman.benchmark("projecthub_api.check_deploy_key.duration", fn ->
      with {:ok, project} <- find_project(req),
           {:ok, response} <- RepositoryHubClient.check_deploy_key(%{repository_id: project.repository.id}) do
        RegenerateDeployKeyResponse.new(
          metadata: status_ok(req),
          deploy_key:
            RegenerateDeployKeyResponse.DeployKey.new(
              title: response.deploy_key.title,
              fingerprint: response.deploy_key.fingerprint,
              created_at: response.deploy_key.created_at,
              public_key: response.deploy_key.public_key
            )
        )
      else
        {:error, :not_found} ->
          CheckDeployKeyResponse.new(metadata: status_not_found(req, req.id))

        # not found
        {:error, %{status: 5}} ->
          CheckDeployKeyResponse.new(metadata: status_not_found(req, req.id))

        {:error, :user_not_found} ->
          message = "Project Owner is no longer a member of a Semaphore."
          CheckDeployKeyResponse.new(metadata: status_failed_precondition(req, message))

        {:error, %{message: message}} ->
          CheckDeployKeyResponse.new(metadata: status_failed_precondition(req, message))
      end
    end)
  end

  defp check_user_permission(project, user_id) do
    RepositoryHubClient.describe_remote_repository(%{
      url: project.repository.url,
      user_id: user_id,
      integration_type: project.repository.integration_type
    })
    |> unwrap(fn response ->
      if response.remote_repository.addable do
        {:ok, ""}
      else
        {:error, %{message: response.remote_repository.reason}}
      end
    end)
  end

  def regenerate_deploy_key(req, _) do
    Watchman.benchmark("projecthub_api.regenerate_deploy_key.duration", fn ->
      with {:ok, project} <- find_project(req),
           {:ok, response} <- RepositoryHubClient.regenerate_deploy_key(%{repository_id: project.repository.id}) do
        RegenerateDeployKeyResponse.new(
          metadata: status_ok(req),
          deploy_key:
            RegenerateDeployKeyResponse.DeployKey.new(
              title: response.deploy_key.title,
              fingerprint: response.deploy_key.fingerprint,
              created_at: response.deploy_key.created_at
            )
        )
      else
        {:error, :not_found} ->
          RegenerateDeployKeyResponse.new(metadata: status_not_found(req, req.id))

        {:error, %{status: 5}} ->
          RegenerateDeployKeyResponse.new(metadata: status_not_found(req, req.id))

        {:error, :user_not_found} ->
          message = "Project Owner is no longer a member of a Semaphore."
          RegenerateDeployKeyResponse.new(metadata: status_failed_precondition(req, message))

        {:error, :permissions_not_an_admin} ->
          message = "OAuth API token owner is not an admin of GitHub repository."
          RegenerateDeployKeyResponse.new(metadata: status_failed_precondition(req, message))

        {:error, :permissions_unauthorized} ->
          message = "OAuth API token owner has broken connection between Semaphore and GitHub."
          RegenerateDeployKeyResponse.new(metadata: status_failed_precondition(req, message))

        {:error, :permissions_not_found} ->
          message = "OAuth API token owner has no access to GitHub repository."
          RegenerateDeployKeyResponse.new(metadata: status_failed_precondition(req, message))

        {:error, :permissions_not_fetched} ->
          message = "There is a problem with connection to GitHub, please try again in a few minutes."

          RegenerateDeployKeyResponse.new(metadata: status_failed_precondition(req, message))

        {:error, :permissions_saml_enforcement} ->
          message =
            "Resource protected by organization SAML enforcement. You must grant your OAuth token access to this organization."

          RegenerateDeployKeyResponse.new(metadata: status_failed_precondition(req, message))

        {:error, %{message: message}} ->
          RegenerateDeployKeyResponse.new(metadata: status_failed_precondition(req, message))
      end
    end)
  end

  def check_webhook(req, _) do
    Watchman.benchmark("projecthub_api.check_webhook.duration", fn ->
      with {:ok, project} <- find_project(req),
           {:ok, response} <- RepositoryHubClient.check_webhook(%{repository_id: project.repository.id}) do
        CheckWebhookResponse.new(
          metadata: status_ok(req),
          webhook: Webhook.new(url: response.webhook.url)
        )
      else
        {:error, :not_found} ->
          CheckWebhookResponse.new(metadata: status_not_found(req, req.id))

        {:error, :user_not_found} ->
          message = "Project Owner is no longer a member of a Semaphore."
          CheckWebhookResponse.new(metadata: status_failed_precondition(req, message))

        {:error, :github_unauthorized} ->
          message = "OAuth API token owner has broken connection between Semaphore and GitHub."
          CheckWebhookResponse.new(metadata: status_failed_precondition(req, message))

        {:error, :github_no_scope} ->
          message = "Semaphore couldn't fetch the webhook from GitHub."
          CheckWebhookResponse.new(metadata: status_failed_precondition(req, message))

        {:error, :github_not_found_private} ->
          message = "Webhook is not present, or OAuth API token owner has no access to the repository."

          CheckWebhookResponse.new(metadata: status_failed_precondition(req, message))

        {:error, :github_not_found_public} ->
          message =
            "Webhook is not present, OAuth API token owner has no access to the repository, or this is a private repository."

          CheckWebhookResponse.new(metadata: status_failed_precondition(req, message))

        {:error, :github_not_found_non} ->
          message = "OAuth API token owner has broken connection between Semaphore and GitHub."
          CheckWebhookResponse.new(metadata: status_failed_precondition(req, message))

        {:error, :webhook_not_active} ->
          message = "Webhook is not active on GitHub."
          CheckWebhookResponse.new(metadata: status_failed_precondition(req, message))

        {:error, :webhook_invalid_url} ->
          message = "Webhooks URL is invalid."
          CheckWebhookResponse.new(metadata: status_failed_precondition(req, message))

        {:error, :webhook_invalid_events} ->
          message = "Webhook is not triggered for proper events."
          CheckWebhookResponse.new(metadata: status_failed_precondition(req, message))

        {:error, :github_not_fetched} ->
          message = "Semaphore couldn't fetch the webhook from GitHub."
          CheckWebhookResponse.new(metadata: status_failed_precondition(req, message))

        {:error, %{message: message}} ->
          CheckWebhookResponse.new(metadata: status_failed_precondition(req, message))
      end
    end)
  end

  def regenerate_webhook(req, _) do
    Watchman.benchmark("projecthub_api.regenerate_webhook.duration", fn ->
      with {:ok, project} <- find_project(req),
           {:ok, response} <- RepositoryHubClient.regenerate_webhook(%{repository_id: project.repository.id}) do
        RegenerateWebhookResponse.new(
          metadata: status_ok(req),
          webhook: Webhook.new(url: response.webhook.url)
        )
      else
        {:error, :not_found} ->
          RegenerateWebhookResponse.new(metadata: status_not_found(req, req.id))

        {:error, :user_not_found} ->
          message = "Project Owner is no longer a member of a Semaphore."
          RegenerateWebhookResponse.new(metadata: status_failed_precondition(req, message))

        {:error, :permissions_not_an_admin} ->
          message = "OAuth API token owner is not an admin of GitHub repository."
          RegenerateWebhookResponse.new(metadata: status_failed_precondition(req, message))

        {:error, :permissions_unauthorized} ->
          message = "OAuth API token owner has broken connection between Semaphore and GitHub."
          RegenerateWebhookResponse.new(metadata: status_failed_precondition(req, message))

        {:error, :permissions_not_found} ->
          message = "OAuth API token owner has no access to GitHub repository."
          RegenerateWebhookResponse.new(metadata: status_failed_precondition(req, message))

        {:error, :permissions_not_fetched} ->
          message = "There is a problem with connection to GitHub, please try again in a few minutes."

          RegenerateWebhookResponse.new(metadata: status_failed_precondition(req, message))

        {:error, :permissions_saml_enforcement} ->
          message =
            "Resource protected by organization SAML enforcement. You must grant your OAuth token access to this organization."

          RegenerateWebhookResponse.new(metadata: status_failed_precondition(req, message))

        {:error, :already_exists} ->
          message = "There is a problem with removing old webhook from GitHub."
          RegenerateWebhookResponse.new(metadata: status_failed_precondition(req, message))

        {:error, %{message: message}} ->
          RegenerateWebhookResponse.new(metadata: status_failed_precondition(req, message))

        {:error, message} ->
          RegenerateWebhookResponse.new(metadata: status_failed_precondition(req, message))
      end
    end)
  end

  def regenerate_webhook_secret(req, _) do
    Watchman.benchmark("projecthub_api.regenerate_webhook_secret.duration", fn ->
      with {:ok, project} <- find_project(req),
           {:ok, response} <- RepositoryHubClient.regenerate_webhook_secret(%{repository_id: project.repository.id}) do
        RegenerateWebhookSecretResponse.new(
          metadata: status_ok(req),
          secret: response.secret
        )
      else
        {:error, message} ->
          RegenerateWebhookSecretResponse.new(metadata: status_failed_precondition(req, message))
      end
    end)
  end

  def change_project_owner(req, _) do
    Watchman.benchmark("projecthub_api.change_project_owner.duration", fn ->
      with {:ok, project} <- find_project(req),
           {:ok, _} <- check_user_permission(project, req.user_id),
           {:ok, _} <-
             Projecthub.Models.Project.update_record(project, %{creator_id: req.user_id}) do
        ChangeProjectOwnerResponse.new(metadata: status_ok(req))
      else
        {:error, :not_found} ->
          ChangeProjectOwnerResponse.new(metadata: status_not_found(req, req.id))

        {:error, :user_not_found} ->
          message = "User is no longer a member of a Semaphore."
          ChangeProjectOwnerResponse.new(metadata: status_failed_precondition(req, message))

        {:error, :permissions_not_an_admin} ->
          message = "User is not an admin of GitHub repository."
          ChangeProjectOwnerResponse.new(metadata: status_failed_precondition(req, message))

        {:error, :permissions_unauthorized} ->
          message = "User has broken connection between Semaphore and GitHub."
          ChangeProjectOwnerResponse.new(metadata: status_failed_precondition(req, message))

        {:error, :permissions_not_found} ->
          message = "User has no access to GitHub repository."
          ChangeProjectOwnerResponse.new(metadata: status_failed_precondition(req, message))

        {:error, :permissions_not_fetched} ->
          message = "There is a problem with connection to GitHub, please try again in a few minutes."

          ChangeProjectOwnerResponse.new(metadata: status_failed_precondition(req, message))

        {:error, :permissions_saml_enforcement} ->
          message =
            "Resource protected by organization SAML enforcement. You must grant your OAuth token access to this organization."

          ChangeProjectOwnerResponse.new(metadata: status_failed_precondition(req, message))

        {:error, %{message: message}} ->
          ChangeProjectOwnerResponse.new(metadata: status_failed_precondition(req, message))
      end
    end)
  end

  def github_app_switch(req, _) do
    alias Projecthub.Models.Repository

    Watchman.benchmark("projecthub_api.github_app_switch.duration", fn ->
      with {:ok, project} <- find_project(req),
           {:ok, _} <-
             Repository.update(project.repository, %{
               integration_type: InternalApi.RepositoryIntegrator.IntegrationType.value(:GITHUB_APP)
             }) do
        GithubAppSwitchResponse.new(metadata: status_ok(req))
      else
        "github_app" ->
          GithubAppSwitchResponse.new(metadata: status_ok(req))

        {:error, :not_found} ->
          GithubAppSwitchResponse.new(metadata: status_not_found(req, req.id))

        {:error, :user_not_found} ->
          message = "User is no longer a member of a Semaphore."
          GithubAppSwitchResponse.new(metadata: status_failed_precondition(req, message))

        {:error, %{message: message}} ->
          GithubAppSwitchResponse.new(metadata: status_failed_precondition(req, message))
      end
    end)
  end

  def finish_onboarding(req, _) do
    alias Projecthub.Models.Project.StateMachine

    Watchman.benchmark("projecthub_api.finish_onboarding.duration", fn ->
      with {:ok, project} <- find_project(req),
           "onboarding" <- project.state,
           {:ok, _} <- StateMachine.transition(project, StateMachine.ready()) do
        FinishOnboardingResponse.new(metadata: status_ok(req))
      else
        "ready" ->
          FinishOnboardingResponse.new(metadata: status_ok(req))

        {:error, :not_found} ->
          GithubAppSwitchResponse.new(metadata: status_not_found(req, req.id))
      end
    end)
  end

  defp find_project(req, soft_deleted \\ false) do
    cond do
      req.id != "" and req.metadata.org_id != "" ->
        Project.find_in_org(req.metadata.org_id, req.id, soft_deleted)

      req.id != "" ->
        Project.find(req.id, soft_deleted)

      req.name != "" ->
        Project.find_by_name(req.name, req.metadata.org_id, soft_deleted)

      true ->
        {:error, :failed_precondition, "Name or ID must be provided"}
    end
    |> unwrap(&Project.preload_repository/1)
    |> wrap()
  end

  defp attempt_creation(
         user,
         org,
         project_metadata,
         project_spec,
         repo_details,
         req,
         integration_type,
         skip_onboarding
       ) do
    case check_preconditions(org, project_metadata) do
      {:error, message} ->
        {:error, message}

      {:ok, nil} ->
        repository = project_spec.repository
        metadata = project_metadata_settings(project_metadata)
        attach = attach_settings(project_spec)
        debug = debug_settings(project_spec)
        run_on = run_settings(project_spec)
        forked_pull_requests = forked_pull_requests_settings(project_spec)
        visibility = project_visibility_settings(org, project_spec)
        schedulers = Scheduler.construct_list(project_spec.schedulers)
        tasks = PeriodicTask.construct(project_spec.tasks, project_metadata.name)

        spec = %{
          public: repo_details.public,
          custom_permissions: project_spec.custom_permissions
        }

        project_params =
          metadata
          |> Map.merge(spec)
          |> Map.merge(attach)
          |> Map.merge(debug)
          |> Map.merge(run_on)
          |> Map.merge(forked_pull_requests)
          |> Map.merge(visibility)

        status = project_spec.repository.status
        whitelist = project_spec.repository.whitelist

        pipeline_file = pipeline_file_value(repository.pipeline_file)

        repo_details =
          Map.merge(repo_details, %{
            pipeline_file: pipeline_file,
            commit_status: status || default_commit_status(pipeline_file),
            whitelist: whitelist || default_whitelist()
          })

        case Project.create(
               req.metadata.req_id,
               user,
               org,
               project_params,
               repo_details,
               integration_type,
               skip_onboarding
             ) do
          {:ok, project} ->
            if Enum.empty?(tasks) do
              Projecthub.Schedulers.update(project, schedulers, user.id)
            else
              PeriodicTask.update_all(project, tasks, user.id)
            end

            {:ok, project}

          {:error, message} ->
            {:error, message}
        end
    end
  end

  defp check_preconditions(org, project_metadata) do
    cond do
      name_taken?(project_metadata, org) ->
        {:error, "Project name '#{project_metadata.name}' is already taken"}

      projects_count_quota_reached?(org) ->
        {:error,
         "The organization has reached a maximum number of projects. To increase the quota, please contact support"}

      true ->
        {:ok, nil}
    end
  end

  defp pipeline_file_value(nil), do: default_pipeline_file()
  defp pipeline_file_value(""), do: default_pipeline_file()
  defp pipeline_file_value(pipeline_file), do: pipeline_file

  defp default_pipeline_file, do: ".semaphore/semaphore.yml"

  defp default_commit_status(pipeline_file) do
    %{"pipeline_files" => [%{"path" => pipeline_file, "level" => "pipeline"}]}
  end

  defp default_whitelist do
    %{"branches" => [], "tags" => []}
  end

  defp attempt_update(project, project_metadata, project_spec, req) do
    repository = project_spec.repository
    schedulers = Scheduler.construct_list(project_spec.schedulers)
    tasks = PeriodicTask.construct(project_spec.tasks, project_metadata.name)
    requester_id = req.metadata.user_id

    metadata = project_metadata_settings(project_metadata)
    spec = project_spec_settings(project_spec)
    attach = attach_settings(project_spec)
    debug = debug_settings(project_spec)
    run_on = run_settings(project_spec)
    forked_pull_requests = forked_pull_requests_settings(project_spec)

    project_params =
      metadata
      |> Map.merge(spec)
      |> Map.merge(attach)
      |> Map.merge(debug)
      |> Map.merge(run_on)
      |> Map.merge(forked_pull_requests)

    status = project_spec.repository.status
    whitelist = project_spec.repository.whitelist

    repo_params =
      reject_empty_strings(%{
        url: repository.url,
        name: repository.name,
        owner: repository.owner,
        pipeline_file: repository.pipeline_file,
        commit_status: status,
        whitelist: whitelist
      })

    case Project.update(
           project,
           project_params,
           repo_params,
           schedulers,
           tasks,
           requester_id,
           req.omit_schedulers_and_tasks
         ) do
      {:ok, updated_project} ->
        UpdateResponse.new(
          metadata: status_ok(req),
          project: serialize(updated_project)
        )

      {:error, messages} when is_list(messages) ->
        UpdateResponse.new(
          metadata:
            status_failed_precondition(
              req,
              Enum.join(messages, ", ")
            )
        )

      {:error, %{message: message}} ->
        UpdateResponse.new(metadata: status_failed_precondition(req, message))

      {:error, message} ->
        UpdateResponse.new(metadata: status_failed_precondition(req, message))
    end
  end

  defp reject_empty_strings(map) do
    Enum.filter(map, fn {_, v} -> v != "" end) |> Enum.into(%{})
  end

  defp attach_settings(%{custom_permissions: false}) do
    %{
      attach_default_branch: false,
      attach_non_default_branch: false,
      attach_pr: false,
      attach_forked_pr: false,
      attach_tag: false
    }
  end

  defp attach_settings(project_spec) do
    attach = project_spec.attach_permissions

    %{
      attach_default_branch: Enum.member?(attach, :DEFAULT_BRANCH),
      attach_non_default_branch: Enum.member?(attach, :NON_DEFAULT_BRANCH),
      attach_pr: Enum.member?(attach, :PULL_REQUEST),
      attach_forked_pr: Enum.member?(attach, :FORKED_PULL_REQUEST),
      attach_tag: Enum.member?(attach, :TAG)
    }
  end

  defp debug_settings(%{custom_permissions: false}) do
    %{
      debug_empty: false,
      debug_default_branch: false,
      debug_non_default_branch: false,
      debug_pr: false,
      debug_forked_pr: false,
      debug_tag: false
    }
  end

  defp debug_settings(project_spec) do
    debug = project_spec.debug_permissions

    %{
      debug_empty: Enum.member?(debug, :EMPTY),
      debug_default_branch: Enum.member?(debug, :DEFAULT_BRANCH),
      debug_non_default_branch: Enum.member?(debug, :NON_DEFAULT_BRANCH),
      debug_pr: Enum.member?(debug, :PULL_REQUEST),
      debug_forked_pr: Enum.member?(debug, :FORKED_PULL_REQUEST),
      debug_tag: Enum.member?(debug, :TAG)
    }
  end

  defp run_settings(project_spec) do
    run_on = project_spec.repository.run_on

    %{
      build_tag: Enum.member?(run_on, :TAGS),
      build_branch: Enum.member?(run_on, :BRANCHES),
      build_pr: Enum.member?(run_on, :PULL_REQUESTS),
      build_forked_pr: Enum.member?(run_on, :FORKED_PULL_REQUESTS)
    }
  end

  defp forked_pull_requests_settings(project_spec) do
    forked_pull_requests = project_spec.repository.forked_pull_requests

    if forked_pull_requests do
      %{
        allowed_secrets: Enum.join(forked_pull_requests.allowed_secrets, ","),
        allowed_contributors: Enum.join(forked_pull_requests.allowed_contributors, ",")
      }
    else
      %{allowed_secrets: "", allowed_contributors: ""}
    end
  end

  defp project_metadata_settings(project_metadata) do
    %{
      name: project_metadata.name,
      description: project_metadata.description
    }
  end

  defp project_spec_settings(project_spec) do
    %{
      public: project_spec.visibility == :PUBLIC,
      custom_permissions: project_spec.custom_permissions
    }
  end

  defp project_visibility_settings(org, _project_spec) do
    public = org.open_source
    %{public: public}
  end

  defp find_user(user_id) when is_binary(user_id) do
    case User.find(user_id) do
      nil -> {:error, :user_not_found}
      user -> {:ok, user}
    end
  end

  defp find_user(req) do
    User.find(req.metadata.user_id)
  end

  defp find_org(req) do
    Organization.find(req.metadata.org_id)
  end

  defp name_taken?(project, org) do
    case Project.find_by_name(project.name, org.id) do
      {:ok, _} -> true
      {:error, :not_found} -> false
    end
  end

  defp projects_count_quota_reached?(org) do
    Project.count_in_org(org.id, false) + 1 > FeatureProvider.feature_quota(:max_projects_in_org, param: org.id)
  end

  defp serialize(project), do: serialize(project, true)

  @spec serialize(project :: any, detailed :: boolean) :: any
  defp serialize(project, false) do
    InternalApi.Projecthub.Project.new(
      metadata: project_metadata(project),
      spec: project_spec(project, [], []),
      status: project_status(project)
    )
  end

  defp serialize(project, true) do
    if FeatureProvider.feature_enabled?(:just_run, param: project.organization_id),
      do: serialize_detailed_with_tasks(project),
      else: serialize_detailed_with_schedulers(project)
  end

  defp serialize_detailed_with_schedulers(project) do
    {:ok, schedulers} = Scheduler.list(project)

    InternalApi.Projecthub.Project.new(
      metadata: project_metadata(project),
      spec: project_spec(project, schedulers, []),
      status: project_status(project)
    )
  end

  defp serialize_detailed_with_tasks(project) do
    {:ok, tasks} = PeriodicTask.list(project)

    InternalApi.Projecthub.Project.new(
      metadata: project_metadata(project),
      spec: project_spec(project, [], tasks),
      status: project_status(project)
    )
  end

  defp project_metadata(project) do
    InternalApi.Projecthub.Project.Metadata.new(
      name: project.name,
      id: project.id,
      owner_id: project.creator_id,
      org_id: project.organization_id,
      description: project.description,
      created_at: Google.Protobuf.Timestamp.new(seconds: DateTime.to_unix(project.created_at))
    )
  end

  defp project_status(project) do
    alias Projecthub.Models.Project.StateMachine
    alias InternalApi.Projecthub.Project.Status.State

    state =
      cond do
        project.state == StateMachine.initializing() -> State.value(:INITIALIZING)
        project.state == StateMachine.initializing_skip() -> State.value(:INITIALIZING)
        project.state == StateMachine.ready() -> State.value(:READY)
        project.state == StateMachine.error() -> State.value(:ERROR)
        project.state == StateMachine.onboarding() -> State.value(:ONBOARDING)
      end

    InternalApi.Projecthub.Project.Status.new(
      state: state,
      state_reason: project.state_reason || "",
      cache: project_cache_status(project),
      artifact_store: project_artifact_store_status(project),
      repository: repository_status(project.repository),
      permissions: permissions_status(project),
      analysis: project_analysis_status(project)
    )
  end

  defp project_cache_status(project) do
    alias InternalApi.Projecthub.Project.Status.State
    alias InternalApi.Projecthub.Project.Status.Cache

    state =
      cond do
        project.cache_id == "" -> State.value(:INITIALIZING)
        project.cache_id == nil -> State.value(:INITIALIZING)
        true -> State.value(:READY)
      end

    Cache.new(state: state)
  end

  defp project_artifact_store_status(project) do
    alias InternalApi.Projecthub.Project.Status.State
    alias InternalApi.Projecthub.Project.Status.ArtifactStore

    state =
      cond do
        project.artifact_store_id == "" -> State.value(:INITIALIZING)
        project.artifact_store_id == nil -> State.value(:INITIALIZING)
        true -> State.value(:READY)
      end

    ArtifactStore.new(state: state)
  end

  defp repository_status(repository) do
    alias InternalApi.Projecthub.Project.Status.State
    alias InternalApi.Projecthub.Project.Status.Repository

    state =
      cond do
        repository.hook_id == "" -> State.value(:INITIALIZING)
        repository.hook_id == nil -> State.value(:INITIALIZING)
        true -> State.value(:READY)
      end

    Repository.new(state: state)
  end

  defp permissions_status(project) do
    alias InternalApi.Projecthub.Project.Status.State
    alias InternalApi.Projecthub.Project.Status.Permissions

    state =
      cond do
        project.permissions_setup == nil -> State.value(:INITIALIZING)
        project.permissions_setup == false -> State.value(:INITIALIZING)
        true -> State.value(:READY)
      end

    Permissions.new(state: state)
  end

  defp project_analysis_status(project) do
    alias InternalApi.Projecthub.Project.Status.State
    alias InternalApi.Projecthub.Project.Status.Analysis

    state =
      if project.analysis == nil do
        State.value(:INITIALIZING)
      else
        State.value(:READY)
      end

    Analysis.new(state: state)
  end

  defp project_spec(project, schedulers, tasks) do
    InternalApi.Projecthub.Project.Spec.new(
      repository: project_repository(project),
      schedulers: project_schedulers(schedulers),
      tasks: project_tasks(tasks),
      public: project.public,
      private: !project.public,
      visibility: project_visibility(project.public),
      custom_permissions: project.custom_permissions,
      debug_permissions: project_debug_permissions(project),
      attach_permissions: project_attach_permissions(project),
      cache_id: safe_string(project.cache_id),
      artifact_store_id: safe_string(project.artifact_store_id),
      docker_registry_id: safe_string(project.docker_registry_id)
    )
  end

  defp project_repository(project) do
    run_on = project_run_on(project)
    run = project_run(run_on)

    InternalApi.Projecthub.Project.Spec.Repository.new(
      id: project.repository.id,
      url: project.repository.url,
      name: project.repository.name,
      owner: project.repository.owner,
      run: run,
      run_on: run_on,
      forked_pull_requests: forked_pull_requests(project),
      pipeline_file: project.repository.pipeline_file,
      status: project.repository.commit_status,
      whitelist: project.repository.whitelist,
      public: !project.repository.private,
      integration_type: project.repository.integration_type,
      default_branch: project.repository.default_branch,
      connected: project.repository.connected
    )
  end

  defp project_visibility(true), do: Visibility.value(:PUBLIC)
  defp project_visibility(false), do: Visibility.value(:PRIVATE)

  defp project_debug_permissions(%{custom_permissions: false}), do: []

  defp project_debug_permissions(project) do
    [
      {:EMPTY, project.debug_empty},
      {:DEFAULT_BRANCH, project.debug_default_branch},
      {:NON_DEFAULT_BRANCH, project.debug_non_default_branch},
      {:PULL_REQUEST, project.debug_pr},
      {:FORKED_PULL_REQUEST, project.debug_forked_pr},
      {:TAG, project.debug_tag}
    ]
    |> Enum.filter(fn e -> elem(e, 1) end)
    |> Enum.map(fn e -> elem(e, 0) end)
    |> Enum.map(fn e -> InternalApi.Projecthub.Project.Spec.PermissionType.value(e) end)
  end

  defp project_attach_permissions(%{custom_permissions: false}), do: []

  defp project_attach_permissions(project) do
    [
      {:DEFAULT_BRANCH, project.attach_default_branch},
      {:NON_DEFAULT_BRANCH, project.attach_non_default_branch},
      {:PULL_REQUEST, project.attach_pr},
      {:FORKED_PULL_REQUEST, project.attach_forked_pr},
      {:TAG, project.attach_tag}
    ]
    |> Enum.filter(fn e -> elem(e, 1) end)
    |> Enum.map(fn e -> elem(e, 0) end)
    |> Enum.map(fn e -> InternalApi.Projecthub.Project.Spec.PermissionType.value(e) end)
  end

  defp project_run_on(project) do
    [
      {:TAGS, project.build_tag},
      {:BRANCHES, project.build_branch},
      {:PULL_REQUESTS, project.build_pr},
      {:FORKED_PULL_REQUESTS, project.build_forked_pr}
    ]
    |> Enum.filter(fn e -> elem(e, 1) end)
    |> Enum.map(fn e -> elem(e, 0) end)
    |> Enum.map(fn e -> InternalApi.Projecthub.Project.Spec.Repository.RunType.value(e) end)
  end

  defp project_run([]), do: false
  defp project_run(_run_on), do: true

  defp forked_pull_requests(project) do
    InternalApi.Projecthub.Project.Spec.Repository.ForkedPullRequests.new(
      allowed_secrets: String.split(project.allowed_secrets, ",", trim: true),
      allowed_contributors: String.split(project.allowed_contributors, ",", trim: true)
    )
  end

  defp project_schedulers([]), do: []

  defp project_schedulers(schedulers) do
    schedulers
    |> Enum.map(fn s ->
      InternalApi.Projecthub.Project.Spec.Scheduler.new(
        id: s.id,
        name: s.name,
        branch: s.branch,
        at: s.at,
        pipeline_file: s.pipeline_file,
        status: s.status
      )
    end)
  end

  defp project_tasks(tasks), do: tasks |> List.wrap() |> Enum.into([], &project_task/1)

  defp project_task(task) do
    alias InternalApi.Projecthub.Project.Spec.Task

    parameters = Enum.into(task.parameters, [], &Task.Parameter.new(&1))
    task |> Map.from_struct() |> Map.put(:parameters, parameters) |> Task.new()
  end

  defp status_ok(req) do
    InternalApi.Projecthub.ResponseMeta.new(
      api_version: req.metadata.api_version,
      kind: req.metadata.kind,
      req_id: req.metadata.req_id,
      org_id: req.metadata.org_id,
      user_id: req.metadata.user_id,
      status: InternalApi.Projecthub.ResponseMeta.Status.new(code: InternalApi.Projecthub.ResponseMeta.Code.value(:OK))
    )
  end

  defp status_not_found(req, project_id \\ nil) do
    identifier =
      if project_id do
        project_id
      else
        if req.id != "", do: req.id, else: req.name
      end

    InternalApi.Projecthub.ResponseMeta.new(
      api_version: req.metadata.api_version,
      kind: req.metadata.kind,
      req_id: req.metadata.req_id,
      org_id: req.metadata.org_id,
      user_id: req.metadata.user_id,
      status:
        InternalApi.Projecthub.ResponseMeta.Status.new(
          code: InternalApi.Projecthub.ResponseMeta.Code.value(:NOT_FOUND),
          message: "project #{identifier} not found"
        )
    )
  end

  defp status_failed_precondition(req, messages)
       when is_list(messages),
       do: status_failed_precondition(req, Enum.join(messages, ", "))

  defp status_failed_precondition(req, message) do
    InternalApi.Projecthub.ResponseMeta.new(
      api_version: req.metadata.api_version,
      kind: req.metadata.kind,
      req_id: req.metadata.req_id,
      org_id: req.metadata.org_id,
      user_id: req.metadata.user_id,
      status:
        InternalApi.Projecthub.ResponseMeta.Status.new(
          code: InternalApi.Projecthub.ResponseMeta.Code.value(:FAILED_PRECONDITION),
          message: message
        )
    )
  end

  def timestamp_to_datetime(%{nanos: 0, seconds: 0}), do: nil

  def timestamp_to_datetime(%{nanos: nanos, seconds: seconds}) do
    ts_in_microseconds = seconds * 1_000_000 + Integer.floor_div(nanos, 1_000)
    {:ok, ts_date_time} = DateTime.from_unix(ts_in_microseconds, :microsecond)
    ts_date_time
  end

  def timestamp_to_datetime(_), do: nil
end
