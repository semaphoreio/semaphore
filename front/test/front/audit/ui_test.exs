defmodule Front.Audit.UI.Test do
  use ExUnit.Case, async: false
  use FrontWeb.ConnCase

  alias Support.Stubs.{DB, UUID}
  alias InternalApi.Audit.Event.{Medium, Operation, Resource}

  setup %{conn: conn} do
    Cacheman.clear(:front)

    Support.Stubs.init()
    Support.Stubs.build_shared_factories()

    user = DB.first(:users)
    organization = DB.first(:organizations)
    org_id = organization.id

    Support.Stubs.Feature.enable_feature(org_id, :audit_logs)
    Support.Stubs.PermissionPatrol.allow_everything(org_id, user.id)

    conn =
      conn
      |> put_req_header("x-semaphore-org-id", org_id)
      |> put_req_header("x-semaphore-user-id", user.id)

    [conn: conn, org_id: org_id]
  end

  defp insert_event(org_id, opts) do
    DB.insert(
      :audit_events,
      Map.merge(
        %{
          org_id: org_id,
          resource: Resource.value(:Secret),
          operation: Operation.value(:Added),
          user_id: UUID.gen(),
          username: "shiroyasha",
          ip_address: "189.0.12.2",
          operation_id: UUID.gen(),
          timestamp: Google.Protobuf.Timestamp.new(seconds: 1_522_754_259),
          resource_id: UUID.gen(),
          resource_name: "my-secret",
          metadata: Poison.encode!(%{"hello" => "world"}),
          medium: Medium.value(:API),
          description: "Added a secret"
        },
        Map.new(opts)
      )
    )
  end

  test "GET /audit/csv streams paginated CSV", %{conn: conn, org_id: org_id} do
    insert_event(org_id, operation: Operation.value(:Added), medium: Medium.value(:API))

    insert_event(org_id,
      operation: Operation.value(:Removed),
      medium: Medium.value(:Web),
      timestamp: Google.Protobuf.Timestamp.new(seconds: 1_522_754_000)
    )

    GrpcMock.stub(AuditMock, :paginated_list, fn _req, _ ->
      events = DB.all(:audit_events) |> Enum.map(&Support.Stubs.AuditLog.Grpc.serialize_event/1)

      InternalApi.Audit.PaginatedListResponse.new(
        events: events,
        next_page_token: "",
        previous_page_token: ""
      )
    end)

    conn = get(conn, "/audit/csv")

    assert conn.status == 200
    assert get_resp_header(conn, "content-type") |> hd() =~ "text/csv"

    body = conn.resp_body
    lines = String.split(body, "\r\n", trim: true)

    assert hd(lines) ==
             "resource,operation,medium,user_id,username,resource_id,resource_name,ip_address,description,metadata,timestamp"

    assert length(lines) == 3
    assert Enum.at(lines, 1) =~ "Secret,Added,API"
    assert Enum.at(lines, 2) =~ "Secret,Removed,Web"
  end

  test "GET /audit/csv streams across multiple pages", %{conn: conn, org_id: org_id} do
    insert_event(org_id, operation: Operation.value(:Added), medium: Medium.value(:API))

    insert_event(org_id,
      operation: Operation.value(:Removed),
      medium: Medium.value(:Web),
      timestamp: Google.Protobuf.Timestamp.new(seconds: 1_522_754_000)
    )

    {:ok, counter} = Agent.start_link(fn -> 0 end)

    GrpcMock.stub(AuditMock, :paginated_list, fn _req, _ ->
      [first, second | _] =
        DB.all(:audit_events) |> Enum.map(&Support.Stubs.AuditLog.Grpc.serialize_event/1)

      case Agent.get_and_update(counter, fn n -> {n, n + 1} end) do
        0 ->
          InternalApi.Audit.PaginatedListResponse.new(
            events: [first],
            next_page_token: "page-2",
            previous_page_token: ""
          )

        _ ->
          InternalApi.Audit.PaginatedListResponse.new(
            events: [second],
            next_page_token: "",
            previous_page_token: ""
          )
      end
    end)

    conn = get(conn, "/audit/csv")

    assert conn.status == 200
    lines = conn.resp_body |> String.split("\r\n", trim: true)
    assert length(lines) == 3
    assert Enum.at(lines, 1) =~ "Secret,Added,API"
    assert Enum.at(lines, 2) =~ "Secret,Removed,Web"
  end

  test "GET /audit/csv returns 502 when first page fails", %{conn: conn} do
    GrpcMock.stub(AuditMock, :paginated_list, fn _req, _ ->
      raise GRPC.RPCError, status: GRPC.Status.unavailable(), message: "audit unavailable"
    end)

    conn = get(conn, "/audit/csv")

    assert conn.status == 502
    assert get_resp_header(conn, "content-disposition") == []
    assert get_resp_header(conn, "content-type") |> hd() =~ "text/plain"
    assert conn.resp_body =~ "Failed to export audit logs"
  end

  test "GET /audit/csv aborts mid-stream on upstream failure (no fake error row)", %{conn: conn} do
    {:ok, counter} = Agent.start_link(fn -> 0 end)

    GrpcMock.stub(AuditMock, :paginated_list, fn _req, _ ->
      case Agent.get_and_update(counter, fn n -> {n, n + 1} end) do
        0 ->
          InternalApi.Audit.PaginatedListResponse.new(
            events: [],
            next_page_token: "page-2",
            previous_page_token: ""
          )

        _ ->
          raise GRPC.RPCError, status: GRPC.Status.unavailable(), message: "boom"
      end
    end)

    assert_raise RuntimeError, ~r/audit_csv_export_upstream_failed/, fn ->
      get(conn, "/audit/csv")
    end
  end

  test "GET /audit/csv aborts when pagination token does not advance", %{conn: conn} do
    GrpcMock.stub(AuditMock, :paginated_list, fn _req, _ ->
      InternalApi.Audit.PaginatedListResponse.new(
        events: [],
        next_page_token: "stuck",
        previous_page_token: ""
      )
    end)

    assert_raise RuntimeError, ~r/audit_csv_export_pagination_stalled/, fn ->
      get(conn, "/audit/csv")
    end
  end
end
