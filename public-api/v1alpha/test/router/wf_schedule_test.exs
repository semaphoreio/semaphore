defmodule PipelinesAPI.Workflows.Schedule.Test do
  use ExUnit.Case

  setup do
    Support.Stubs.grant_all_permissions()
    :ok
  end

  test "POST /workflows/ - 403 when user does not have permission" do
    GrpcMock.stub(RBACMock, :list_user_permissions, fn _, _ ->
      InternalApi.RBAC.ListUserPermissionsResponse.new(
        permissions: Support.Stubs.all_permissions_except("project.job.rerun")
      )
    end)

    org = Support.Stubs.Organization.create_default()
    user = Support.Stubs.User.create_default()
    project = Support.Stubs.Project.create(org, user)

    params = %{
      "project_id" => project.id,
      "reference" => "master",
      "commit_sha" => "1234",
      "pipeline_file" => ".semaphore/semaphore.yml"
    }

    assert "Not Found" = create_workflow(params, 404)
  end

  test "POST /workflows/ - successful when server returns :OK response" do
    org = Support.Stubs.Organization.create_default()
    user = Support.Stubs.User.create_default()
    Support.Stubs.Project.create(org, user, id: "project_1")

    params = %{
      "project_id" => "project_1",
      "reference" => "master",
      "commit_sha" => "1234",
      "pipeline_file" => ".semaphore/semaphore.yml"
    }

    assert body = create_workflow(params, 200)
    assert {:ok, response} = Poison.decode(body)
    assert {:ok, _} = UUID.info(response["workflow_id"])
    assert {:ok, _} = UUID.info(response["pipeline_id"])
  end

  test "POST /workflows/ - returns 400 when server returns :invalid_argument response" do
    org = Support.Stubs.Organization.create_default()
    user = Support.Stubs.User.create_default()
    Support.Stubs.Project.create(org, user, id: "invalid_arg")

    params = %{
      "project_id" => "invalid_arg",
      "reference" => "master",
      "commit_sha" => "1234",
      "pipeline_file" => ".semaphore/semaphore.yml"
    }

    assert "\"Invalid argument\"" = create_workflow(params, 400)
  end

  test "POST /workflows/ - returns 400 when server returns :failed_precondition response" do
    org = Support.Stubs.Organization.create_default()
    user = Support.Stubs.User.create_default()
    Support.Stubs.Project.create(org, user, id: "project_deleted")

    params = %{
      "project_id" => "project_deleted",
      "reference" => "master",
      "commit_sha" => "1234",
      "pipeline_file" => ".semaphore/semaphore.yml"
    }

    assert "\"Failed precondition\"" = create_workflow(params, 400)
  end

  test "POST /workflows/ - returns 400 when server returns :resource_exhausted response" do
    org = Support.Stubs.Organization.create_default()
    user = Support.Stubs.User.create_default()
    Support.Stubs.Project.create(org, user, id: "resource_exhausted")

    params = %{
      "project_id" => "resource_exhausted",
      "reference" => "master",
      "commit_sha" => "1234",
      "pipeline_file" => ".semaphore/semaphore.yml"
    }

    assert "\"Resource exhausted\"" = create_workflow(params, 400)
  end

  test "POST /workflows/ - returns 500 when there is an internal error on server" do
    org = Support.Stubs.Organization.create_default()
    user = Support.Stubs.User.create_default()
    Support.Stubs.Project.create(org, user, id: "internal_error")

    params = %{
      "project_id" => "internal_error",
      "reference" => "master",
      "commit_sha" => "1234",
      "pipeline_file" => ".semaphore/semaphore.yml"
    }

    assert "\"Internal error\"" = create_workflow(params, 500)
  end

  def create_workflow(params, expected_status_code) do
    {:ok, response} = params |> Poison.encode!() |> create()
    %{:body => body, :status_code => status_code} = response
    if(status_code != expected_status_code, do: IO.puts("Response body: #{inspect(body)}"))
    assert status_code == expected_status_code
    body
  end

  def url, do: "localhost:4004"

  def headers() do
    [
      {"Content-type", "application/json"},
      {"x-semaphore-user-id", Support.Stubs.User.default_user_id()},
      {"x-semaphore-org-id", Support.Stubs.Organization.default_org_id()}
    ]
  end

  defp create(body) do
    HTTPoison.post(url() <> "/workflows", body, headers())
  end
end
