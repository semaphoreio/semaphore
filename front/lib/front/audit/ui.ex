defmodule Front.Audit.UI do
  require Logger

  alias Front.Audit.EventsDecorator
  alias InternalApi.Audit.Event.{Medium, Operation, Resource}
  alias InternalApi.Audit.PaginatedListRequest.Direction

  @csv_headers [
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

  @csv_page_size 500

  def stream_csv(conn, org_id) do
    endpoint = Application.fetch_env!(:front, :audit_grpc_endpoint)
    {:ok, channel} = GRPC.Stub.connect(endpoint)

    header_row = [@csv_headers] |> CSV.encode() |> Enum.to_list()

    case send_chunks(conn, header_row) do
      {:ok, conn} ->
        stream_csv_pages(conn, channel, org_id, "")

      {:error, conn} ->
        Logger.error("Audit CSV export failed: client disconnected during header send")
        conn
    end
  end

  defp stream_csv_pages(conn, channel, org_id, page_token) do
    request =
      InternalApi.Audit.PaginatedListRequest.new(
        org_id: org_id,
        page_size: @csv_page_size,
        page_token: page_token,
        direction: Direction.value(:NEXT)
      )

    case InternalApi.Audit.AuditService.Stub.paginated_list(channel, request) do
      {:ok, res} ->
        csv_rows =
          res.events
          |> Enum.map(&event_to_csv_row/1)
          |> CSV.encode()
          |> Enum.to_list()

        case send_chunks(conn, csv_rows) do
          {:ok, conn} ->
            if res.next_page_token not in ["", nil] do
              stream_csv_pages(conn, channel, org_id, res.next_page_token)
            else
              conn
            end

          {:error, conn} ->
            Logger.error("Audit CSV export failed: client disconnected during data send")
            conn
        end

      {:error, reason} ->
        Logger.error("Audit CSV export failed during pagination: #{inspect(reason)}")

        error_row = [
          [
            "ERROR",
            "Export failed - audit data may be incomplete",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            ""
          ]
        ]

        error_csv = error_row |> CSV.encode() |> Enum.to_list()

        send_chunks(conn, error_csv)
        |> elem(1)
    end
  end

  defp send_chunks(conn, chunks) do
    Enum.reduce_while(chunks, {:ok, conn}, fn chunk, {:ok, acc} ->
      case Plug.Conn.chunk(acc, chunk) do
        {:ok, conn} -> {:cont, {:ok, conn}}
        {:error, _reason} -> {:halt, {:error, acc}}
      end
    end)
  end

  defp event_to_csv_row(e) do
    [
      Resource.key(e.resource),
      Operation.key(e.operation),
      Medium.key(e.medium),
      e.user_id || "",
      e.username || "",
      e.resource_id || "",
      e.resource_name || "",
      e.ip_address || "",
      e.description || "",
      to_string(e.metadata || ""),
      if(e.timestamp, do: e.timestamp.seconds, else: "")
    ]
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
