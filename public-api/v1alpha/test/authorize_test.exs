defmodule PipelinesAPI.AuthorizeTest do
  use ExUnit.Case
  use Plug.Test

  alias PipelinesAPI.Pipelines.Authorize

  @uuid "f5672bab-d123-75a5-fa31-4c2f9ffae4b7"

  setup do
    Support.Stubs.grant_all_permissions()

    :ok
  end

  test "successfully authorizes list request" do
    org = Support.Stubs.Organization.create_default()
    user = Support.Stubs.User.create_default()
    Support.Stubs.Project.create(org, user, id: @uuid)

    conn =
      conn(:get, "/pipelines?project_id=#{@uuid}")
      |> put_req_header("x-semaphore-org-id", Support.Stubs.Organization.default_org_id())
      |> put_req_header("x-semaphore-user-id", Support.Stubs.User.default_user_id())
      |> Plug.Conn.fetch_query_params()

    conn = Authorize.authorize_read_list(conn, %{})
    assert conn.halted == false
  end

  test "successfully authorizes schedule request with project_id in json payload" do
    org = Support.Stubs.Organization.create_default()
    user = Support.Stubs.User.create_default()
    project = Support.Stubs.Project.create(org, user, id: @uuid)
    json_payload = %{project_id: project.id}

    conn =
      conn(:post, "/pipelines", Poison.encode!(json_payload))
      |> put_req_header("x-semaphore-org-id", Support.Stubs.Organization.default_org_id())
      |> put_req_header("x-semaphore-user-id", Support.Stubs.User.default_user_id())
      |> put_req_header("content-type", "application/json")
      |> parse

    conn = Authorize.authorize_create(conn, "opts")
    assert conn.halted == false
  end

  test "successfully authorizes describe request with ppl_id in url" do
    user_id = UUID.uuid4()
    hook = %{id: UUID.uuid4(), project_id: UUID.uuid4(), branch_id: UUID.uuid4()}
    workflow = Support.Stubs.Workflow.create(hook, user_id)
    pipeline = Support.Stubs.Pipeline.create_initial(workflow)

    conn =
      conn(:get, "/pipelines/#{@uuid}")
      |> put_req_header("x-semaphore-user-id", "test")
      |> put_req_header("x-semaphore-org-id", "test_org")
      |> Map.put(:params, %{"pipeline_id" => pipeline.id})

    conn = Authorize.authorize_read(conn, "opts")
    assert conn.halted == false
  end

  test "successfully authorizes validate_yaml call with ppl_id in yaml payload" do
    user_id = UUID.uuid4()
    hook = %{id: UUID.uuid4(), project_id: UUID.uuid4(), branch_id: UUID.uuid4()}
    workflow = Support.Stubs.Workflow.create(hook, user_id)
    pipeline = Support.Stubs.Pipeline.create_initial(workflow)

    yaml_payload = %{pipeline_id: pipeline.id}

    conn =
      conn(:post, "/yaml", Poison.encode!(yaml_payload))
      |> put_req_header("x-semaphore-user-id", "test")
      |> put_req_header("x-semaphore-org-id", "test_org")
      |> put_req_header("content-type", "application/json")
      |> parse

    conn = Authorize.authorize_create(conn, "opts")
    assert conn.halted == false
  end

  test "no permissions needed when yaml payload has no pipeline_id" do
    GrpcMock.stub(RBACMock, :list_user_permissions, fn _, _ ->
      InternalApi.RBAC.ListUserPermissionsResponse.new(permissions: [])
    end)

    conn =
      conn(:post, "/yaml", Poison.encode!(%{}))
      |> put_req_header("x-semaphore-user-id", "test")
      |> put_req_header("content-type", "application/json")
      |> parse

    conn = Authorize.authorize_create_with_ppl_in_payload(conn, "opts")
    assert conn.halted == false
  end

  test "halts when user has no access to resource" do
    GrpcMock.stub(RBACMock, :list_user_permissions, fn _, _ ->
      InternalApi.RBAC.ListUserPermissionsResponse.new(permissions: [])
    end)

    conn =
      conn(:get, "/pipelines?project_id=#{@uuid}")
      |> put_req_header("x-semaphore-user-id", "fail_user_id")
      |> Map.put(:params, %{"pipeline_id" => "123"})

    conn = Authorize.authorize_read(conn, "opts")
    assert conn.halted == true
  end

  defp parse(conn) do
    opts = [
      pass: ["application/json"],
      json_decoder: Poison,
      parsers: [Plug.Parsers.JSON]
    ]

    Plug.Parsers.call(conn, Plug.Parsers.init(opts))
  end
end
