defmodule Secrethub.Audit do
  @moduledoc """
  Collect and log Audit logs.

  Example usage for sending Audit logs:

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

  def new(conn, resource, operation) do
    [
      org_id: header(conn, "x-semaphore-org-id"),
      user_id: header(conn, "x-semaphore-user-id"),
      operation_id: header(conn, "x-request-id") || Logger.metadata()[:request_id],
      resource: InternalApi.Audit.Event.Resource.value(resource),
      operation: InternalApi.Audit.Event.Operation.value(operation),
      ip_address: ip(conn) || "",
      medium: InternalApi.Audit.Event.Medium.value(api_or_cli(conn)),
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

    event =
      audit
      |> Keyword.merge(
        metadata: Poison.encode!(metadata),
        timestamp: Google.Protobuf.Timestamp.new(seconds: :os.system_time(:seconds))
      )
      |> InternalApi.Audit.Event.new()
      |> InternalApi.Audit.Event.encode()

    url = Application.get_env(:secrethub, :amqp_url)
    options = %{url: url, exchange: "audit", routing_key: "log"}

    :ok = Tackle.publish(event, options)

    audit
  end

  defp header(conn, name) do
    conn |> GRPC.Stream.get_headers() |> Map.get(name)
  end

  defp api_or_cli(conn) do
    user_agent = header(conn, "grpcgateway-User-Agent") || ""

    if String.match?(user_agent, ~r/SemaphoreCLI.*/), do: :CLI, else: :API
  end

  defp ip(conn) do
    (header(conn, "x-forwarded-for") || "")
    |> String.split(", ")
    |> List.first()
  end
end
