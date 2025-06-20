defmodule Projecthub.HttpApi do
  alias Projecthub.{Auth, Organization, Utils}

  require Logger

  use Plug.Router

  unless Mix.env() == :dev || Mix.env() == :test do
    use Plug.ErrorHandler
    use Sentry.Plug
  end

  plug(:assign_req_id)
  plug(:assign_user_id)
  plug(:assign_org_id)
  plug(:assign_version)

  @version "v1alpha"

  plug(Plug.Logger, log: :debug)
  plug(Plug.Parsers, parsers: [:json], json_decoder: Poison)
  plug(:match)
  plug(:dispatch)

  #
  # Health checks
  #

  get "/" do
    send_resp(conn, 200, "world")
  end

  get "/is_alive" do
    send_resp(conn, 200, "world")
  end

  #
  # Rest API
  #

  get "/api/#{@version}/projects" do
    case list_projects(conn) do
      {:ok, {projects, page, has_more}} ->
        conn
        |> put_resp_header("x-page", Integer.to_string(page))
        |> put_resp_header("x-has-more", to_string(has_more))
        |> send_resp(200, Poison.encode!(projects))

      {:error, :not_found} ->
        send_resp(conn, 404, Poison.encode!(%{message: "Not found"}))

      {:error, message} ->
        send_resp(conn, 400, Poison.encode!(%{message: message}))
    end
  end

  get "/api/#{@version}/projects/:name" do
    user_id = conn.assigns.user_id
    org_id = conn.assigns.org_id

    project_rsp = fetch_project(conn)
    restricted = Organization.restricted?(org_id)

    case project_rsp do
      {:ok, project} ->
        if Auth.has_permissions?(org_id, user_id, project.metadata.id, "project.view") do
          send_resp(conn, 200, encode(project, restricted))
        else
          send_resp(conn, 401, Poison.encode!(%{message: "Unauthorized"}))
        end

      {:error, :not_found} ->
        send_resp(conn, 404, Poison.encode!(%{message: "Not found"}))

      {:error, message} ->
        send_resp(conn, 400, Poison.encode!(%{message: message}))
    end
  end

  post "/api/#{@version}/projects" do
    alias InternalApi.Projecthub.Project.Spec.Repository

    user_id = conn.assigns.user_id
    org_id = conn.assigns.org_id

    if Auth.has_permissions?(org_id, user_id, "organization.projects.create") do
      restricted = Organization.restricted?(org_id)

      spec = conn.body_params["spec"]
      repository = spec["repository"]

      {schedulers, tasks} = construct_schedulers_and_tasks(conn.body_params)

      req =
        InternalApi.Projecthub.CreateRequest.new(
          skip_onboarding: skip_onboarding_map(conn.body_params["skip_onboarding"]),
          metadata: Utils.construct_req_meta(conn),
          project:
            InternalApi.Projecthub.Project.new(
              metadata:
                InternalApi.Projecthub.Project.Metadata.new(
                  name: conn.body_params["metadata"]["name"]
                ),
              spec:
                InternalApi.Projecthub.Project.Spec.new(
                  repository:
                    Repository.new(
                      url: repository["url"],
                      forked_pull_requests:
                        Repository.ForkedPullRequests.new(
                          allowed_secrets:
                            repository["forked_pull_requests"]["allowed_secrets"] || [],
                          allowed_contributors:
                            repository["forked_pull_requests"]["allowed_contributors"] || []
                        ),
                      run_on: run_on_map(repository["run_on"]),
                      pipeline_file: repository["pipeline_file"] || "",
                      status: status_map(repository["status"]),
                      whitelist: whitelist_map(repository["whitelist"]),
                      integration_type:
                        integration_type_map(
                          repository["integration_type"],
                          repository["url"],
                          conn.assigns.org_id
                        )
                    ),
                  schedulers: schedulers,
                  tasks: tasks,
                  visibility: visibility_map(spec["visibility"]),
                  custom_permissions: custom_permissions_map(spec["custom_permissions"]),
                  debug_permissions: permissions_map(spec["debug_permissions"]),
                  attach_permissions: permissions_map(spec["attach_permissions"])
                )
            )
        )

      Logger.info("Constructed request info #{inspect(req)}")

      {:ok, channel} =
        GRPC.Stub.connect(Application.fetch_env!(:projecthub, :projecthub_grpc_endpoint))

      {:ok, res} =
        InternalApi.Projecthub.ProjectService.Stub.create(channel, req, timeout: 30_000)

      Logger.info("Sending response #{inspect(res)}")

      case InternalApi.Projecthub.ResponseMeta.Code.key(res.metadata.status.code) do
        :OK ->
          send_resp(conn, 200, encode(res.project, restricted))

        :FAILED_PRECONDITION ->
          send_resp(conn, 422, Poison.encode!(%{message: res.metadata.status.message}))
      end
    else
      send_resp(conn, 401, Poison.encode!(%{message: "Unauthorized"}))
    end
  end

  @update_permissions ["project.general_settings.manage", "project.repository_info.manage"]
  patch "/api/#{@version}/projects/:id" do
    alias InternalApi.Projecthub.Project.Spec.Repository

    user_id = conn.assigns.user_id
    org_id = conn.assigns.org_id
    project_id = conn.params["id"]

    if Auth.has_permissions?(org_id, user_id, project_id, @update_permissions) do
      metadata = conn.body_params["metadata"]
      spec = conn.body_params["spec"]
      repository = spec["repository"]

      {schedulers, tasks} = construct_schedulers_and_tasks(conn.body_params)

      restricted = Organization.restricted?(org_id)

      req =
        InternalApi.Projecthub.UpdateRequest.new(
          metadata: Utils.construct_req_meta(conn),
          project:
            InternalApi.Projecthub.Project.new(
              metadata:
                InternalApi.Projecthub.Project.Metadata.new(
                  id: conn.params["id"],
                  name: metadata["name"],
                  description: metadata["description"] || ""
                ),
              spec:
                InternalApi.Projecthub.Project.Spec.new(
                  repository:
                    Repository.new(
                      url: repository["url"],
                      forked_pull_requests:
                        Repository.ForkedPullRequests.new(
                          allowed_secrets:
                            repository["forked_pull_requests"]["allowed_secrets"] || [],
                          allowed_contributors:
                            repository["forked_pull_requests"]["allowed_contributors"] || []
                        ),
                      run_on: run_on_map(repository["run_on"]),
                      pipeline_file:
                        conn.body_params["spec"]["repository"]["pipeline_file"] || "",
                      status: status_map(repository["status"]),
                      whitelist: whitelist_map(repository["whitelist"])
                    ),
                  schedulers: schedulers,
                  tasks: tasks,
                  visibility: visibility_map(conn.body_params["spec"]["visibility"]),
                  custom_permissions: custom_permissions_map(spec["custom_permissions"]),
                  debug_permissions: permissions_map(spec["debug_permissions"]),
                  attach_permissions: permissions_map(spec["attach_permissions"])
                )
            )
        )

      Logger.info("Constructed request info #{inspect(req)}")

      {:ok, channel} =
        GRPC.Stub.connect(Application.fetch_env!(:projecthub, :projecthub_grpc_endpoint))

      {:ok, res} =
        InternalApi.Projecthub.ProjectService.Stub.update(channel, req, timeout: 30_000)

      Logger.info("Sending response #{inspect(res)}")

      case InternalApi.Projecthub.ResponseMeta.Code.key(res.metadata.status.code) do
        :OK ->
          send_resp(conn, 200, encode(res.project, restricted))

        :NOT_FOUND ->
          send_resp(conn, 404, Poison.encode!(%{message: "Not found"}))

        :FAILED_PRECONDITION ->
          send_resp(conn, 422, Poison.encode!(%{message: res.metadata.status.message}))
      end
    else
      send_resp(conn, 401, Poison.encode!(%{message: "Unauthorized"}))
    end
  end

  delete "/api/#{@version}/projects/:name" do
    user_id = conn.assigns.user_id
    org_id = conn.assigns.org_id

    with {:ok, project_id} <- get_project_id(conn),
         true <- Auth.has_permissions?(org_id, user_id, project_id, "project.delete") do
      req =
        InternalApi.Projecthub.DestroyRequest.new(
          metadata: Utils.construct_req_meta(conn),
          name: conn.params["name"]
        )

      Logger.info("Constructed request info #{inspect(req)}")

      {:ok, channel} =
        GRPC.Stub.connect(Application.fetch_env!(:projecthub, :projecthub_grpc_endpoint))

      {:ok, res} =
        InternalApi.Projecthub.ProjectService.Stub.destroy(channel, req, timeout: 30_000)

      Logger.info("Sending response #{inspect(res)}")

      case InternalApi.Projecthub.ResponseMeta.Code.key(res.metadata.status.code) do
        :OK -> send_resp(conn, 200, "")
        _ -> send_resp(conn, 400, Poison.encode!(%{message: "Bad Request"}))
      end
    else
      _ ->
        send_resp(conn, 401, Poison.encode!(%{message: "Unauthorized"}))
    end
  end

  #
  # Fallback for unhandled paths
  #

  match _ do
    send_resp(conn, 404, "oops")
  end

  #
  # Utils
  #

  defp get_project_id(conn) do
    req =
      InternalApi.Projecthub.DescribeRequest.new(
        metadata: Utils.construct_req_meta(conn),
        name: conn.params["name"]
      )

    {:ok, channel} =
      GRPC.Stub.connect(Application.fetch_env!(:projecthub, :projecthub_grpc_endpoint))

    {:ok, res} =
      InternalApi.Projecthub.ProjectService.Stub.describe(channel, req, timeout: 30_000)

    case InternalApi.Projecthub.ResponseMeta.Code.key(res.metadata.status.code) do
      :OK -> {:ok, res.project.metadata.id}
      _ -> {:error, nil}
    end
  end

  defp run_on_map(values) do
    valid_types =
      InternalApi.Projecthub.Project.Spec.Repository.RunType.__message_props__().field_tags
      |> Map.keys()

    (values || [])
    |> Enum.map(fn type ->
      type = type |> String.upcase() |> String.to_atom()

      if Enum.member?(valid_types, type) do
        InternalApi.Projecthub.Project.Spec.Repository.RunType.value(type)
      else
        nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp skip_onboarding_map("true"), do: true
  defp skip_onboarding_map("false"), do: false
  defp skip_onboarding_map(value) when is_boolean(value), do: value
  defp skip_onboarding_map(_), do: true

  defp custom_permissions_map("true"), do: true
  defp custom_permissions_map(value) when is_boolean(value), do: value
  defp custom_permissions_map(_), do: false

  defp permissions_map(values) do
    valid_types =
      InternalApi.Projecthub.Project.Spec.PermissionType.__message_props__().field_tags
      |> Map.keys()

    (values || [])
    |> Enum.map(fn type ->
      type = type |> String.upcase() |> String.to_atom()

      if Enum.member?(valid_types, type) do
        InternalApi.Projecthub.Project.Spec.PermissionType.value(type)
      else
        nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp integration_type_map("github_app", _, _),
    do: InternalApi.RepositoryIntegrator.IntegrationType.value(:GITHUB_APP)

  defp integration_type_map("github_token", _, _),
    do: InternalApi.RepositoryIntegrator.IntegrationType.value(:GITHUB_OAUTH_TOKEN)

  defp integration_type_map("bitbucket", _, _),
    do: InternalApi.RepositoryIntegrator.IntegrationType.value(:BITBUCKET)

  defp integration_type_map("gitlab", _, _),
    do: InternalApi.RepositoryIntegrator.IntegrationType.value(:GITLAB)

  defp integration_type_map("git", _, _),
    do: InternalApi.RepositoryIntegrator.IntegrationType.value(:GIT)

  defp integration_type_map(_, _, _org_id),
    do: InternalApi.RepositoryIntegrator.IntegrationType.value(:GITHUB_OAUTH_TOKEN)

  defp visibility_map("private"),
    do: InternalApi.Projecthub.Project.Spec.Visibility.value(:PRIVATE)

  defp visibility_map("public"), do: InternalApi.Projecthub.Project.Spec.Visibility.value(:PUBLIC)
  defp visibility_map(_), do: visibility_map("private")
  defp whitelist_map(nil), do: nil

  defp whitelist_map(whitelist) do
    InternalApi.Projecthub.Project.Spec.Repository.Whitelist.new(
      branches: whitelist["branches"] || [],
      tags: whitelist["tags"] || []
    )
  end

  defp status_map(nil), do: nil

  defp status_map(status) do
    InternalApi.Projecthub.Project.Spec.Repository.Status.new(
      pipeline_files: pipeline_files_map(status["pipeline_files"])
    )
  end

  defp pipeline_files_map(nil), do: []

  defp pipeline_files_map(values) do
    alias InternalApi.Projecthub.Project.Spec.Repository.Status.PipelineFile
    valid_levels = PipelineFile.Level.__message_props__().field_tags |> Map.keys()

    values
    |> Enum.map(fn file ->
      level = file["level"] |> String.upcase() |> String.to_atom()

      if Enum.member?(valid_levels, level) do
        level = PipelineFile.Level.value(level)

        PipelineFile.new(path: file["path"], level: level)
      else
        nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp assign_req_id(conn, _) do
    assign(conn, :req_id, conn |> get_req_header("x-request-id") |> List.first())
  end

  defp assign_org_id(conn, _) do
    assign(conn, :org_id, conn |> get_req_header("x-semaphore-org-id") |> List.first())
  end

  defp assign_user_id(conn, _) do
    assign(conn, :user_id, conn |> get_req_header("x-semaphore-user-id") |> List.first())
  end

  defp assign_version(conn, _) do
    assign(conn, :version, @version)
  end

  def encode(proto_projects, restricted) when is_list(proto_projects) do
    proto_projects
    |> Enum.map(fn proto_project ->
      encode_project(proto_project, restricted)
      |> Map.merge(%{"apiVersion" => @version, "kind" => "Project"})
    end)
    |> Poison.encode!()
  end

  def encode(proto_project, restricted) do
    encode_project(proto_project, restricted)
    |> Map.merge(%{"apiVersion" => @version, "kind" => "Project"})
    |> Poison.encode!()
  end

  defp encode_project(p, restricted) do
    alias InternalApi.Projecthub.Project.Spec.Visibility

    metadata = %{
      "description" => p.metadata.description,
      "id" => p.metadata.id,
      "name" => p.metadata.name,
      "org_id" => p.metadata.org_id,
      "owner_id" => p.metadata.owner_id
    }

    spec = %{
      "repository" => %{
        "name" => p.spec.repository.name,
        "owner" => p.spec.repository.owner,
        "url" => p.spec.repository.url,
        "forked_pull_requests" => %{
          "allowed_secrets" => p.spec.repository.forked_pull_requests.allowed_secrets,
          "allowed_contributors" => p.spec.repository.forked_pull_requests.allowed_contributors
        },
        "run_on" => map_run_types(p.spec.repository.run_on),
        "pipeline_file" => p.spec.repository.pipeline_file,
        "status" => encode_status(p.spec.repository.status),
        "whitelist" => encode_whitelist(p.spec.repository.whitelist),
        "integration_type" => encode_inegration_type(p.spec.repository.integration_type)
      },
      "schedulers" => encode_schedulers(p.spec.schedulers),
      "tasks" => encode_tasks(p.spec.tasks),
      "visibility" => Visibility.key(p.spec.visibility) |> from_atom()
    }

    debugs = %{
      "custom_permissions" => p.spec.custom_permissions,
      "debug_permissions" => map_permission_types(p.spec.debug_permissions),
      "attach_permissions" => map_permission_types(p.spec.attach_permissions)
    }

    if restricted do
      %{"metadata" => metadata, "spec" => Map.merge(spec, debugs)}
    else
      %{"metadata" => metadata, "spec" => spec}
    end
  end

  defp encode_inegration_type(0), do: "github_token"
  defp encode_inegration_type(1), do: "github_app"
  defp encode_inegration_type(2), do: "bitbucket"
  defp encode_inegration_type(3), do: "gitlab"
  defp encode_inegration_type(4), do: "git"
  defp encode_inegration_type(_), do: ""

  defp encode_whitelist(nil), do: %{"branches" => [], "tags" => []}

  defp encode_whitelist(whitelist) do
    %{
      "branches" => whitelist.branches,
      "tags" => whitelist.tags
    }
  end

  @unspecified_status InternalApi.Projecthub.Project.Spec.Scheduler.Status.value(
                        :STATUS_UNSPECIFIED
                      )
  @status_active InternalApi.Projecthub.Project.Spec.Scheduler.Status.value(:STATUS_ACTIVE)
  @status_inactive InternalApi.Projecthub.Project.Spec.Scheduler.Status.value(:STATUS_INACTIVE)
  defp encode_schedulers(schedulers) do
    alias InternalApi.Projecthub.Project.Spec.Scheduler

    schedulers
    |> Enum.map(fn scheduler ->
      case scheduler.status do
        @unspecified_status ->
          Map.delete(scheduler, :status)

        _ ->
          Map.put(scheduler, :status, encode_scheduler_status(scheduler.status))
      end
    end)
  end

  defp encode_scheduler_status(@status_inactive), do: "INACTIVE"
  defp encode_scheduler_status(@status_active), do: "ACTIVE"

  @task_unspecified_status InternalApi.Projecthub.Project.Spec.Task.Status.value(
                             :STATUS_UNSPECIFIED
                           )
  @task_status_active InternalApi.Projecthub.Project.Spec.Task.Status.value(:STATUS_ACTIVE)
  @task_status_inactive InternalApi.Projecthub.Project.Spec.Task.Status.value(:STATUS_INACTIVE)
  defp encode_tasks(tasks) do
    tasks
    |> Stream.map(fn task ->
      case task.status do
        @task_unspecified_status ->
          Map.delete(task, :status)

        _ ->
          Map.put(task, :status, encode_task_status(task.status))
      end
    end)
    |> Stream.map(&Map.put(&1, :scheduled, &1.recurring))
    |> Enum.map(&Map.delete(&1, :recurring))
  end

  defp encode_task_status(@task_status_inactive), do: "INACTIVE"
  defp encode_task_status(@task_status_active), do: "ACTIVE"

  defp map_run_types(types) do
    alias InternalApi.Projecthub.Project.Spec.Repository.RunType, as: Type

    Enum.map(types, fn type -> Type.key(type) |> from_atom() end)
  end

  defp map_permission_types(types) do
    alias InternalApi.Projecthub.Project.Spec.PermissionType, as: Type

    Enum.map(types, fn type -> Type.key(type) |> from_atom() end)
  end

  defp encode_status(nil), do: %{"pipeline_files" => []}

  defp encode_status(status) do
    alias InternalApi.Projecthub.Project.Spec.Repository.Status.PipelineFile.Level

    %{
      "pipeline_files" =>
        status.pipeline_files
        |> Enum.map(fn file ->
          %{
            "path" => file.path,
            "level" => Level.key(file.level) |> from_atom()
          }
        end)
    }
  end

  defp from_atom(atom) do
    atom
    |> Atom.to_string()
    |> String.downcase()
  end

  defp construct_schedulers_and_tasks(body_params) do
    schedulers = construct_schedulers(body_params["spec"]["schedulers"])
    tasks = construct_tasks(body_params["spec"]["tasks"])

    if Enum.empty?(tasks),
      do: {schedulers, []},
      else: {[], tasks}
  end

  defp construct_schedulers(raw_schedulers) do
    alias InternalApi.Projecthub.Project.Spec.Scheduler

    if raw_schedulers do
      raw_schedulers
      |> Enum.map(fn scheduler ->
        Scheduler.new(
          id: scheduler["id"] || "",
          name: scheduler["name"],
          branch: scheduler["branch"],
          at: scheduler["at"],
          pipeline_file: scheduler["pipeline_file"],
          status: scheduler_status(scheduler["status"])
        )
      end)
    else
      []
    end
  end

  defp construct_tasks(raw_tasks) do
    alias InternalApi.Projecthub.Project.Spec.Task, as: SpecTask

    if raw_tasks do
      raw_tasks
      |> Enum.map(fn task ->
        SpecTask.new(
          id: task["id"] || "",
          name: task["name"],
          description: task["description"] || "",
          recurring: if(is_nil(task["scheduled"]), do: true, else: task["scheduled"]),
          branch: task["branch"] || "",
          at: task["at"] || "",
          pipeline_file: task["pipeline_file"] || "",
          parameters: construct_task_parameters(task["parameters"]),
          status: task_status(task["status"])
        )
      end)
    else
      []
    end
  end

  defp construct_task_parameters(raw_task_parameters) do
    alias InternalApi.Projecthub.Project.Spec.Task.Parameter, as: SpecTaskParameter

    if raw_task_parameters do
      raw_task_parameters
      |> Enum.map(fn task_parameter ->
        SpecTaskParameter.new(
          name: task_parameter["name"],
          required: task_parameter["required"],
          description: task_parameter["description"] || "",
          default_value: task_parameter["default_value"] || "",
          options: task_parameter["options"] || []
        )
      end)
    else
      []
    end
  end

  defp scheduler_status(status),
    do: InternalApi.Projecthub.Project.Spec.Scheduler.Status.value(scheduler_status_(status))

  defp scheduler_status_(nil), do: :STATUS_UNSPECIFIED
  defp scheduler_status_(""), do: :STATUS_UNSPECIFIED
  defp scheduler_status_("ACTIVE"), do: :STATUS_ACTIVE
  defp scheduler_status_("INACTIVE"), do: :STATUS_INACTIVE
  defp scheduler_status_(_), do: :STATUS_UNSPECIFIED

  defp task_status(status),
    do: InternalApi.Projecthub.Project.Spec.Task.Status.value(task_status_(status))

  defp task_status_(nil), do: :STATUS_UNSPECIFIED
  defp task_status_(""), do: :STATUS_UNSPECIFIED
  defp task_status_("ACTIVE"), do: :STATUS_ACTIVE
  defp task_status_("INACTIVE"), do: :STATUS_INACTIVE
  defp task_status_(_), do: :STATUS_UNSPECIFIED

  defp fetch_project(conn) do
    req =
      InternalApi.Projecthub.DescribeRequest.new(
        metadata: Utils.construct_req_meta(conn),
        name: conn.params["name"],
        detailed: true
      )

    {:ok, channel} =
      GRPC.Stub.connect(Application.fetch_env!(:projecthub, :projecthub_grpc_endpoint))

    {:ok, res} =
      InternalApi.Projecthub.ProjectService.Stub.describe(channel, req, timeout: 30_000)

    case InternalApi.Projecthub.ResponseMeta.Code.key(res.metadata.status.code) do
      :OK -> {:ok, res.project}
      :NOT_FOUND -> {:error, :not_found}
      _ -> {:error, "Bad Request"}
    end
  end

  defp list_projects(conn) do
    org_id = conn.assigns.org_id
    restricted = Organization.restricted?(org_id)

    case parse_int(conn.params, "page", 1, 100, 1) do
      {:ok, page} -> do_list_projects(conn, org_id, restricted, page)
      {:error, reason} -> {:error, reason}
    end
  end

  defp page_size, do: Application.get_env(:projecthub, :projects_page_size, 500)

  defp do_list_projects(conn, org_id, restricted, page) do
    req =
      InternalApi.Projecthub.ListRequest.new(
        metadata: Utils.construct_req_meta(conn),
        pagination:
          InternalApi.Projecthub.PaginationRequest.new(
            page: page,
            page_size: page_size()
          )
      )

    {:ok, channel} =
      GRPC.Stub.connect(Application.fetch_env!(:projecthub, :projecthub_grpc_endpoint))

    {:ok, res} = InternalApi.Projecthub.ProjectService.Stub.list(channel, req, timeout: 30_000)

    case InternalApi.Projecthub.ResponseMeta.Code.key(res.metadata.status.code) do
      :OK ->
        projects =
          res.projects
          |> Auth.filter_projects(org_id, conn.assigns.user_id)
          |> Enum.map(&encode_project(&1, restricted))
          |> Enum.map(&Map.merge(&1, %{"apiVersion" => @version, "kind" => "Project"}))

        total = Map.get(res.pagination || %{}, :total_entries, 0)
        has_more = (page - 1) * page_size() + length(res.projects) < total

        if total < (page - 1) * page_size() do
          {:ok, {[], page, false}}
        else
          {:ok, {projects, page, has_more}}
        end

      :NOT_FOUND ->
        {:error, :not_found}

      _ ->
        {:error, "Bad Request"}
    end
  end

  defp parse_int(params, key, min, max, default) do
    case Map.get(params, key) do
      nil ->
        {:ok, default}

      str when is_binary(str) ->
        case Integer.parse(str) do
          {n, ""} when n >= min and n <= max -> {:ok, n}
          {n, ""} when n < min -> {:error, "#{key} must be at least #{min}"}
          {n, ""} when n > max -> {:error, "#{key} must be at most #{max}"}
          _ -> {:error, "#{key} must be a number"}
        end

      _ ->
        {:error, "#{key} must be a number"}
    end
  end
end
