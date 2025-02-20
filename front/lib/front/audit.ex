defmodule Front.Audit do
  @moduledoc """
  Collect and log Audit logs.

  Example usage for sending Audit logs from a Phoenix controller that works with
  Secrets.

  1. Create a new audit for the Secret resource, Modified operation. Find the full
    list of Resources and Operations in InternalApi.Audit.Event proto message.

    audit = Audit.new(conn, :Secret, :Modified)

  2. Add information into the Audit.Event. Find the list of fields in the
    InternalApi.Audit.Event proto message.

    audit = Audit.add(audit, :resource_id, secret.id)
    audit = Audit.add(audit, :resource_name, secret.name)

  3. Add metadata to the Audit Event. Metadata is any non-essential but possibly
  helpful data that adds information to the event.

    audit = Audit.metadata(audit, env_var_count: 12)

  4. Log the event.

    Audit.log(audit)
  """
  require Logger

  def new(conn, resource, operation) do
    [
      org_id: header(conn, "x-semaphore-org-id"),
      user_id: header(conn, "x-semaphore-user-id"),
      operation_id: header(conn, "x-request-id") || Logger.metadata()[:request_id],
      resource: InternalApi.Audit.Event.Resource.value(resource),
      operation: InternalApi.Audit.Event.Operation.value(operation),
      ip_address: ip(conn) || "",
      metadata: %{}
    ]
  end

  def add(audit, name, value) do
    Keyword.merge(audit, [{name, value}])
  end

  def add(audit, params) do
    Keyword.merge(audit, params)
  end

  def metadata(audit, meta) do
    metadata = Keyword.fetch!(audit, :metadata)
    metadata = Map.merge(metadata, Enum.into(meta, %{}))

    Keyword.put(audit, :metadata, metadata)
  end

  def log(audit) do
    metadata = Keyword.fetch!(audit, :metadata)

    message =
      audit
      |> Keyword.merge(
        metadata: Poison.encode!(metadata),
        timestamp: Google.Protobuf.Timestamp.new(seconds: :os.system_time(:seconds))
      )
      |> InternalApi.Audit.Event.new()
      |> InternalApi.Audit.Event.encode()

    push_audit_log(message)

    audit
  end

  defp push_audit_log(message) do
    if Application.get_env(:front, :audit_logging) do
      exchange_name = "audit"
      routing_key = "log"
      {:ok, channel} = AMQP.Application.get_channel(:audit)
      Tackle.Exchange.create(channel, exchange_name)
      :ok = Tackle.Exchange.publish(channel, exchange_name, message, routing_key)
    else
      Logger.info(%{type: "AuditLog", message: message})
    end
  end

  defp header(conn, name) do
    conn |> Plug.Conn.get_req_header(name) |> List.first()
  end

  defp ip(conn) do
    (header(conn, "x-forwarded-for") || "")
    |> String.split(", ")
    |> List.first()
  end
end
