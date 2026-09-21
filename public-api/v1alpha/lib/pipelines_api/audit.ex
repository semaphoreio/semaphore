defmodule PipelinesAPI.Audit do
  @moduledoc """
  Collect and publish audit log events for v1alpha API endpoints.
  """

  require Logger
  alias Plug.Conn
  alias PipelinesAPI.Util.Map, as: MapUtil

  @exchange_name "audit"
  @routing_key "log"
  @audit_channel :audit
  @cli_user_agent_regex ~r/SemaphoreCLI.*/

  def log_artifact_download(conn, params) when is_map(params) do
    conn
    |> new(:Artifact, :Download)
    |> add(resource_name: artifact_resource_name(params))
    |> metadata(
      source_kind: Map.get(params, "scope", ""),
      source_id: Map.get(params, "scope_id", ""),
      project_id: Map.get(params, "project_id", ""),
      request_method: Map.get(params, "method", "GET")
    )
    |> log()
  end

  def log_artifact_list(conn, params, returned_count \\ nil) when is_map(params) do
    payload = %{
      type: "AuditLog",
      event: "artifact_operation",
      user_id: header(conn, "x-semaphore-user-id") || "",
      org_id: header(conn, "x-semaphore-org-id") || "",
      operation_id: header(conn, "x-request-id") || Logger.metadata()[:request_id] || "",
      resource: "Artifact",
      operation: "List",
      resource_name: artifact_resource_name(params),
      medium: api_or_cli(conn),
      source_kind: Map.get(params, "scope", ""),
      source_id: Map.get(params, "scope_id", ""),
      project_id: Map.get(params, "project_id", ""),
      returned_count: returned_count
    }

    Logger.info(payload)
  end

  def log_workflow_rebuild(conn, workflow) when is_map(workflow) do
    workflow_id = MapUtil.get(workflow, "wf_id", "")

    conn
    |> new(:Workflow, :Rebuild)
    |> add(resource_name: workflow_id)
    |> add(description: "Rebuilt the workflow")
    |> metadata(
      project_id: MapUtil.get(workflow, "project_id", ""),
      branch_name: MapUtil.get(workflow, "branch_name", ""),
      workflow_id: workflow_id,
      commit_sha: MapUtil.get(workflow, "commit_sha", "")
    )
    |> log()
  end

  def new(conn, resource, operation) do
    [
      org_id: header(conn, "x-semaphore-org-id") || "",
      user_id: header(conn, "x-semaphore-user-id") || "",
      operation_id: header(conn, "x-request-id") || Logger.metadata()[:request_id] || "",
      resource: InternalApi.Audit.Event.Resource.value(resource),
      operation: InternalApi.Audit.Event.Operation.value(operation),
      ip_address: ip(conn) || "",
      username: "",
      description: "",
      resource_id: "",
      resource_name: "",
      medium: InternalApi.Audit.Event.Medium.value(api_or_cli(conn)),
      metadata: %{}
    ]
  end

  def add(audit, name, value), do: Keyword.merge(audit, [{name, value}])
  def add(audit, params), do: Keyword.merge(audit, params)

  def metadata(audit, meta) do
    metadata =
      audit
      |> Keyword.fetch!(:metadata)
      |> Map.merge(Enum.into(meta, %{}))

    Keyword.put(audit, :metadata, metadata)
  end

  def log(audit) do
    metadata = Keyword.fetch!(audit, :metadata)

    event =
      audit
      |> Keyword.merge(
        metadata: Poison.encode!(metadata),
        timestamp: Google.Protobuf.Timestamp.new(seconds: :os.system_time(:seconds))
      )
      |> InternalApi.Audit.Event.new()

    case push_audit_log(event) do
      :ok ->
        {:ok, audit}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp push_audit_log(event) do
    Logger.info(stdout_log_payload(event))

    if audit_publish_enabled?(event) do
      message = InternalApi.Audit.Event.encode(event)

      case publish_audit_log(message) do
        :ok ->
          :ok

        {:error, reason} ->
          Logger.error("Failed to publish audit log through AMQP: #{inspect(reason)}")
          {:error, reason}
      end
    else
      :ok
    end
  rescue
    error ->
      Logger.error(
        "Failed to push audit log: #{inspect(error)}\n#{Exception.format_stacktrace(__STACKTRACE__)}"
      )

      {:error, error}
  end

  defp audit_publish_enabled?(event) do
    Application.get_env(:pipelines_api, :audit_logging, false) &&
      audit_logs_feature_enabled?(event.org_id)
  end

  defp audit_logs_feature_enabled?(org_id) when is_binary(org_id) and org_id != "" do
    FeatureProvider.feature_enabled?(:audit_logs, param: org_id)
  rescue
    error ->
      Logger.error("Failed to check audit_logs feature: #{inspect(error)}")
      false
  end

  defp audit_logs_feature_enabled?(_org_id), do: false

  defp publish_audit_log(message) do
    case audit_publish_fun_override() do
      publish_fun when is_function(publish_fun, 1) ->
        publish_fun.(message)

      _ ->
        publish_audit_log_amqp(message)
    end
  end

  defp publish_audit_log_amqp(message) do
    with {:ok, channel} <- AMQP.Application.get_channel(@audit_channel),
         _exchange <- Tackle.Exchange.create(channel, @exchange_name),
         :ok <- Tackle.Exchange.publish(channel, @exchange_name, message, @routing_key) do
      :ok
    else
      error -> {:error, error}
    end
  end

  defp audit_publish_fun_override do
    Application.get_env(:pipelines_api, :audit_publish_fun)
  end

  defp stdout_log_payload(event) do
    resource = enum_value_name(InternalApi.Audit.Event.Resource, event.resource)
    operation = enum_value_name(InternalApi.Audit.Event.Operation, event.operation)
    medium = enum_value_name(InternalApi.Audit.Event.Medium, event.medium)

    %{
      type: "AuditLog",
      event: event_type_name(resource),
      user_id: event.user_id,
      org_id: event.org_id,
      operation_id: event.operation_id,
      resource_name: event.resource_name,
      resource: resource,
      operation: operation,
      medium: medium
    }
  end

  defp enum_value_name(enum_module, value) do
    case enum_module.key(value) do
      nil -> to_string(value)
      enum_value -> enum_value |> Atom.to_string()
    end
  rescue
    _ -> to_string(value)
  end

  defp event_type_name("Artifact"), do: "artifact_operation"
  defp event_type_name("Workflow"), do: "workflow_operation"
  defp event_type_name(_), do: "audit_operation"

  defp artifact_resource_name(params) do
    [
      "artifacts",
      normalize_path_component(Map.get(params, "scope")),
      normalize_path_component(Map.get(params, "scope_id")),
      normalize_path_component(Map.get(params, "path"))
    ]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("/")
  end

  defp normalize_path_component(value) when is_binary(value) do
    value
    |> String.trim()
    |> String.trim("/")
  end

  defp normalize_path_component(_value), do: ""

  defp header(conn, name) do
    conn
    |> Conn.get_req_header(name)
    |> List.first()
  end

  defp api_or_cli(conn) do
    user_agent = header(conn, "user-agent") || ""

    if String.match?(user_agent, @cli_user_agent_regex), do: :CLI, else: :API
  end

  defp ip(conn) do
    (header(conn, "x-forwarded-for") || "")
    |> String.split(", ")
    |> List.first()
  end
end
