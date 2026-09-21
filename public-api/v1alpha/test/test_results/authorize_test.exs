defmodule PipelinesAPI.TestResults.AuthorizeTest do
  use ExUnit.Case
  use Plug.Test

  alias PipelinesAPI.TestResults.Authorize

  setup do
    Support.Stubs.reset()
    Support.Stubs.grant_all_permissions()
    Cachex.clear(:project_api_cache)
    :ok
  end

  test "passes through when caller has project.view and project belongs to org" do
    org = Support.Stubs.Organization.create_default()
    user = Support.Stubs.User.create_default()
    project = Support.Stubs.Project.create(org, user)

    conn =
      conn(:get, "/projects/#{project.id}/test_results/flaky_tests")
      |> put_req_header("x-semaphore-org-id", org.id)
      |> put_req_header("x-semaphore-user-id", user.id)
      |> Map.put(:params, %{"project_id" => project.id})
      |> Authorize.authorize_read([])

    refute conn.halted
  end

  test "halts 404 when caller has no project.view" do
    org = Support.Stubs.Organization.create_default()
    user = Support.Stubs.User.create_default()
    project = Support.Stubs.Project.create(org, user)

    GrpcMock.stub(RBACMock, :list_user_permissions, fn _, _ ->
      InternalApi.RBAC.ListUserPermissionsResponse.new(
        permissions: Support.Stubs.all_permissions_except("project.view")
      )
    end)

    conn =
      conn(:get, "/projects/#{project.id}/test_results/flaky_tests")
      |> put_req_header("x-semaphore-org-id", org.id)
      |> put_req_header("x-semaphore-user-id", user.id)
      |> Map.put(:params, %{"project_id" => project.id})
      |> Authorize.authorize_read([])

    assert conn.halted
    assert conn.status == 404
  end

  test "halts 404 when project belongs to a different org" do
    org1 = Support.Stubs.Organization.create_default()
    org2 = Support.Stubs.Organization.create(name: "RT2", org_username: "rt2")
    user = Support.Stubs.User.create_default()
    project_in_org1 = Support.Stubs.Project.create(org1, user)

    conn =
      conn(:get, "/projects/#{project_in_org1.id}/test_results/flaky_tests")
      |> put_req_header("x-semaphore-org-id", org2.id)
      |> put_req_header("x-semaphore-user-id", user.id)
      |> Map.put(:params, %{"project_id" => project_in_org1.id})
      |> Authorize.authorize_read([])

    assert conn.halted
    assert conn.status == 404
  end

  test "halts 404 when org_id header is missing" do
    org = Support.Stubs.Organization.create_default()
    user = Support.Stubs.User.create_default()
    project = Support.Stubs.Project.create(org, user)

    conn =
      conn(:get, "/projects/#{project.id}/test_results/flaky_tests")
      |> put_req_header("x-semaphore-user-id", user.id)
      |> Map.put(:params, %{"project_id" => project.id})
      |> Authorize.authorize_read([])

    assert conn.halted
    assert conn.status == 404
  end
end
