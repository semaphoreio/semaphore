defmodule PipelinesAPI.Audit do
  @moduledoc """
  Collect and publish audit log events for v1alpha API endpoints.
  """

  require Logger
  alias Plug.Conn

  @exchange_name "audit"
  @routing_key "log"
  @audit_channel :audit
  @cli_user_agent_regex ~r/SemaphoreCLI.*/

  def log_artifact_download(conn, params) when is_map(params) do
    conn
    |> new(:Artifact, :Download)
    |> add(resource_name: Map.get(params, "path", ""))
    |> metadata(
      source_kind: Map.get(params, "scope", ""),
      source_id: Map.get(params, "scope_id", ""),
      project_id: Map.get(params, "project_id", ""),
      request_method: Map.get(params, "method", "GET")
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

    message = InternalApi.Audit.Event.encode(event)

    push_audit_log(event, message)

    audit
  end

  defp push_audit_log(event, message) do
    fallback_log = fallback_log_payload(event, message)

    if Application.get_env(:pipelines_api, :audit_logging, false) do
      case publish_audit_log(message) do
        :ok ->
          :ok

        {:error, reason} ->
          Logger.error("Failed to publish audit log through AMQP: #{inspect(reason)}")
          Logger.info(fallback_log)
      end
    else
      Logger.info(fallback_log)
    end
  rescue
    error ->
      Logger.error("Failed to push audit log: #{inspect(error)}")
      Logger.info(fallback_log_payload(event, message))
  end

  defp publish_audit_log(message) do
    with {:ok, channel} <- AMQP.Application.get_channel(@audit_channel),
         :ok <- Tackle.Exchange.create(channel, @exchange_name),
         :ok <- Tackle.Exchange.publish(channel, @exchange_name, message, @routing_key) do
      :ok
    else
      error -> {:error, error}
    end
  end

  defp fallback_log_payload(event, message) do
    %{
      type: "AuditLog",
      message: message,
      user_id: event.user_id,
      org_id: event.org_id,
      operation_id: event.operation_id,
      resource_name: event.resource_name
    }
  end

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
