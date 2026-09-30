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

  describe "GET /audit/csv with a date range" do
    setup do
      {:ok, requests} = Agent.start_link(fn -> [] end)

      GrpcMock.stub(AuditMock, :paginated_list, fn req, _ ->
        Agent.update(requests, &[req | &1])

        InternalApi.Audit.PaginatedListResponse.new(
          events: [],
          next_page_token: if(req.page_token == "", do: "page-2", else: ""),
          previous_page_token: ""
        )
      end)

      [requests: requests]
    end

    defp sent_requests(requests), do: requests |> Agent.get(& &1) |> Enum.reverse()

    test "no range sends no bounds (old behaviour)", %{conn: conn, requests: requests} do
      conn = get(conn, "/audit/csv")

      assert conn.status == 200

      assert get_resp_header(conn, "content-disposition") == [
               ~s(attachment; filename="audit.csv")
             ]

      for req <- sent_requests(requests) do
        assert req.from_timestamp == nil
        assert req.to_timestamp == nil
      end
    end

    test "empty params are the same as no range", %{conn: conn, requests: requests} do
      conn = get(conn, "/audit/csv", %{"from" => "", "to" => ""})

      assert conn.status == 200
      assert [%{from_timestamp: nil, to_timestamp: nil} | _] = sent_requests(requests)
    end

    test "sends the range as UTC day bounds on every page, 'to' day inclusive", %{
      conn: conn,
      requests: requests
    } do
      conn = get(conn, "/audit/csv", %{"from" => "2026-09-01", "to" => "2026-09-30"})

      assert conn.status == 200

      assert get_resp_header(conn, "content-disposition") == [
               ~s(attachment; filename="audit_2026-09-01_2026-09-30.csv")
             ]

      from = DateTime.to_unix(~U[2026-09-01 00:00:00Z])
      to = DateTime.to_unix(~U[2026-10-01 00:00:00Z])

      sent = sent_requests(requests)
      assert length(sent) == 2

      for req <- sent do
        assert req.from_timestamp.seconds == from
        assert req.to_timestamp.seconds == to
      end
    end

    test "a single day covers that whole day", %{conn: conn, requests: requests} do
      conn = get(conn, "/audit/csv", %{"from" => "2026-02-28", "to" => "2026-02-28"})

      assert conn.status == 200
      [req | _] = sent_requests(requests)
      assert req.from_timestamp.seconds == DateTime.to_unix(~U[2026-02-28 00:00:00Z])
      assert req.to_timestamp.seconds == DateTime.to_unix(~U[2026-03-01 00:00:00Z])
    end

    test "open-ended ranges", %{conn: conn, requests: requests} do
      conn = get(conn, "/audit/csv", %{"from" => "2026-09-01"})
      assert conn.status == 200

      assert get_resp_header(conn, "content-disposition") == [
               ~s(attachment; filename="audit_2026-09-01_now.csv")
             ]

      [req | _] = sent_requests(requests)
      assert req.from_timestamp.seconds == DateTime.to_unix(~U[2026-09-01 00:00:00Z])
      assert req.to_timestamp == nil

      Agent.update(requests, fn _ -> [] end)

      conn = get(conn, "/audit/csv", %{"to" => "2026-09-01"})
      assert conn.status == 200
      [req | _] = sent_requests(requests)
      assert req.from_timestamp == nil
      assert req.to_timestamp.seconds == DateTime.to_unix(~U[2026-09-02 00:00:00Z])
    end

    test "'from' after 'to' is a 400 and never calls the audit service", %{
      conn: conn,
      requests: requests
    } do
      conn = get(conn, "/audit/csv", %{"from" => "2026-09-30", "to" => "2026-09-01"})

      assert conn.status == 400
      assert conn.resp_body =~ "must not be after"
      assert get_resp_header(conn, "content-disposition") == []
      assert sent_requests(requests) == []
    end

    test "malformed dates are a 400", %{conn: conn, requests: requests} do
      for params <- [
            %{"from" => "yesterday"},
            %{"to" => "2026-13-01"},
            %{"from" => "2026-09-01T00:00:00Z"},
            %{"from" => ["2026-09-01"]},
            %{"to" => "2026-09-01\r\nX-Injected: 1"},
            %{"to" => "9999-12-31"},
            %{"from" => "1969-12-31"}
          ] do
        conn = get(conn, "/audit/csv", params)

        assert conn.status == 400, "expected 400 for #{inspect(params)}"
        assert get_resp_header(conn, "content-disposition") == []
      end

      assert sent_requests(requests) == []
    end

    test "INVALID_ARGUMENT from the audit service is a 400, not a 502", %{conn: conn} do
      GrpcMock.stub(AuditMock, :paginated_list, fn _req, _ ->
        raise GRPC.RPCError,
          status: GRPC.Status.invalid_argument(),
          message: "to_timestamp is out of range"
      end)

      conn = get(conn, "/audit/csv", %{"to" => "2026-09-01"})

      assert conn.status == 400
      assert conn.resp_body =~ "to_timestamp is out of range"
    end
  end
end
