defmodule Front.Audit.UI do
  alias Front.Audit.EventsDecorator
  alias InternalApi.Audit.Event.{Medium, Operation, Resource}
  alias InternalApi.Audit.PaginatedListRequest.Direction

  def csv(org_id) do
    endpoint = Application.fetch_env!(:front, :audit_grpc_endpoint)
    request = InternalApi.Audit.ListRequest.new(org_id: org_id)

    {:ok, channel} = GRPC.Stub.connect(endpoint)
    {:ok, res} = InternalApi.Audit.AuditService.Stub.list(channel, request)

    res.events
    |> Enum.sort(fn e1, e2 ->
      e1.timestamp.seconds > e2.timestamp.seconds
    end)
    |> Enum.map(fn e ->
      %{
        "resource" => Resource.key(e.resource),
        "operation" => Operation.key(e.operation),
        "medium" => Medium.key(e.medium),
        "user_id" => e.user_id,
        "username" => e.username,
        "resource_id" => e.resource_id,
        "resource_name" => e.resource_name,
        "ip_address" => e.ip_address,
        "description" => e.description,
        "metadata" => e.metadata,
        "timestamp" => e.timestamp.seconds
      }
    end)
    |> CSV.encode(
      headers: [
        "resource",
        "operation",
        "medium",
        "user_id",
        "username",
        "resource_id",
        "resource_name",
        "ip_address",
        "description",
        "metadata",
        "timestamp"
      ]
    )
    |> Enum.to_list()
  end

  def list_events(org_id, page_token, direction, page_size \\ 30) do
    endpoint = Application.fetch_env!(:front, :audit_grpc_endpoint)

    request =
      InternalApi.Audit.PaginatedListRequest.new(
        org_id: org_id,
        page_size: page_size,
        page_token: page_token,
        direction: direction(direction)
      )

    {:ok, channel} = GRPC.Stub.connect(endpoint)
    {:ok, res} = InternalApi.Audit.AuditService.Stub.paginated_list(channel, request)

    {EventsDecorator.decorate(res.events), res.next_page_token, res.previous_page_token}
  end

  def list_stream_logs(org_id, page_token, direction, page_size \\ 10) do
    endpoint = Application.fetch_env!(:front, :audit_grpc_endpoint)

    request =
      InternalApi.Audit.ListStreamLogsRequest.new(
        org_id: org_id,
        page_size: page_size,
        page_token: page_token,
        direction: direction(direction)
      )

    {:ok, channel} = GRPC.Stub.connect(endpoint)
    {:ok, res} = InternalApi.Audit.AuditService.Stub.list_stream_logs(channel, request)

    %{logs: res.stream_logs, next_page: res.next_page_token, prev_page: res.previous_page_token}
  end

  defp direction("next"), do: Direction.value(:NEXT)
  defp direction("previous"), do: Direction.value(:PREVIOUS)
  defp direction(_), do: direction("next")
end
