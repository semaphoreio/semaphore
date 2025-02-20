defmodule Front.AuditTest do
  use FrontWeb.ConnCase

  @org_id Ecto.UUID.generate()
  @user_id Ecto.UUID.generate()
  @req_id Ecto.UUID.generate()
  @ips "1.1.1.1, 2.2.2.2"

  setup do
    conn =
      build_conn()
      |> Plug.Conn.put_req_header("x-semaphore-org-id", @org_id)
      |> Plug.Conn.put_req_header("x-semaphore-user-id", @user_id)
      |> Plug.Conn.put_req_header("x-request-id", @req_id)
      |> Plug.Conn.put_req_header("x-forwarded-for", @ips)

    {:ok, %{conn: conn}}
  end

  test "creating new audit logs from a Phoenix connection", %{conn: conn} do
    assert Front.Audit.new(conn, :Secret, :Added) == [
             org_id: @org_id,
             user_id: @user_id,
             operation_id: @req_id,
             resource: 6,
             operation: 0,
             ip_address: "1.1.1.1",
             metadata: %{}
           ]
  end

  test "adding data to the audit log", %{conn: conn} do
    audit =
      conn
      |> Front.Audit.new(:Secret, :Added)
      |> Front.Audit.add(description: "Hello")
      |> Front.Audit.add(resource_id: "123")
      |> Front.Audit.add(resource_name: "my-secret")

    assert audit == [
             org_id: @org_id,
             user_id: @user_id,
             operation_id: @req_id,
             resource: 6,
             operation: 0,
             ip_address: "1.1.1.1",
             metadata: %{},
             description: "Hello",
             resource_id: "123",
             resource_name: "my-secret"
           ]
  end

  test "publishing the log", %{conn: conn} do
    audit =
      conn
      |> Front.Audit.new(:Secret, :Added)
      |> Front.Audit.add(description: "Hello")
      |> Front.Audit.add(resource_id: "123")
      |> Front.Audit.add(resource_name: "my-secret")
      |> Front.Audit.metadata(project_name: "Hello")

    # if everything is :ok_hand: we simply return the sent audit log
    assert Front.Audit.log(audit) == audit
  end
end
