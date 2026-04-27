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

  test "GET /audit/csv streams paginated CSV", %{conn: conn, org_id: org_id} do
    DB.insert(:audit_events, %{
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
    })

    DB.insert(:audit_events, %{
      org_id: org_id,
      resource: Resource.value(:Secret),
      operation: Operation.value(:Removed),
      user_id: UUID.gen(),
      username: "shiroyasha",
      ip_address: "189.0.12.2",
      operation_id: UUID.gen(),
      timestamp: Google.Protobuf.Timestamp.new(seconds: 1_522_754_000),
      resource_id: UUID.gen(),
      resource_name: "my-secret",
      metadata: Poison.encode!(%{"hello" => "world"}),
      medium: Medium.value(:Web),
      description: "Removed a secret"
    })

    # Stub paginated_list to return events then empty next_page_token to stop pagination
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
end
