defmodule PipelinesAPI.Schedules.RunNow.Test do
  use ExUnit.Case

  setup do
    Support.Stubs.grant_all_permissions()
    :ok
  end

  test "POST /schedules/:id/run_now - project ID mismatch" do
    org = Support.Stubs.Organization.create(name: "RT2", org_username: "rt2")
    user = Support.Stubs.User.create_default()
    project = Support.Stubs.Project.create(org, user)
    scheduler = Support.Stubs.Scheduler.create(project.id, user.id)

    params = %{
      "branch" => "master",
      "pipeline_file" => ".semaphore/semaphore.yml",
      "parameters" => %{
        "param1" => "value1",
        "param2" => "value2"
      }
    }

    assert "Not Found" = post_run_now(params, scheduler.id, 404, false)
  end

  test "POST /schedules/:id/run_now - no permission" do
    GrpcMock.stub(RBACMock, :list_user_permissions, fn _, _ ->
      InternalApi.RBAC.ListUserPermissionsResponse.new(
        permissions: Support.Stubs.all_permissions_except("project.scheduler.run_manually")
      )
    end)

    org = Support.Stubs.Organization.create_default()
    user = Support.Stubs.User.create_default()
    project = Support.Stubs.Project.create(org, user)
    scheduler = Support.Stubs.Scheduler.create(project.id, user.id)

    params = %{
      "branch" => "master",
      "pipeline_file" => ".semaphore/semaphore.yml",
      "parameters" => %{
        "param1" => "value1",
        "param2" => "value2"
      }
    }

    assert "Not Found" = post_run_now(params, scheduler.id, 404, false)
  end

  test "POST /schedules/:id/run_now - RESOURCE_EXHAUSTED response from the server" do
    org = Support.Stubs.Organization.create_default()
    user = Support.Stubs.User.create_default()
    project = Support.Stubs.Project.create(org, user)
    scheduler = Support.Stubs.Scheduler.create(project.id, user.id)

    params = %{
      "branch" => "RESOURCE_EXHAUSTED",
      "pipeline_file" => ".semaphore/semaphore.yml",
      "parameters" => %{
        "param1" => "value1",
        "param2" => "value2"
      }
    }

    assert "\"RESOURCE_EXHAUSTED message from server\"" =
             post_run_now(params, scheduler.id, 400, false)
  end

  test "POST /schedules/:id/run_now - success when running a schedule and PeriodicSch returns :OK" do
    org = Support.Stubs.Organization.create_default()
    user = Support.Stubs.User.create_default()
    project = Support.Stubs.Project.create(org, user)
    scheduler = Support.Stubs.Scheduler.create(project.id, user.id)

    params = %{
      "branch" => "master",
      "pipeline_file" => ".semaphore/semaphore.yml",
      "parameters" => %{
        "param1" => "value1",
        "param2" => "value2"
      }
    }

    assert %{"workflow_id" => workflow_id} = post_run_now(params, scheduler.id, 200)
    assert {:ok, _} = UUID.info(workflow_id)

    assert Support.Stubs.DB.find_all_by(:triggers, :periodic_id, scheduler.id) |> Enum.count() > 0
  end

  def post_run_now(args, id, expected_status_code, decode \\ true)
      when is_map(args) do
    {:ok, response} = args |> Poison.encode!() |> post_schedules_request(id)
    %{:body => body, :status_code => status_code} = response
    if(status_code != expected_status_code, do: IO.puts("Response body: #{inspect(body)}"))
    assert status_code == expected_status_code

    if decode do
      Poison.decode!(body)
    else
      body
    end
  end

  def url, do: "localhost:4004"

  def headers() do
    [
      {"Content-type", "application/json"},
      {"x-semaphore-user-id", Support.Stubs.User.default_user_id()},
      {"x-semaphore-org-id", Support.Stubs.Organization.default_org_id()}
    ]
  end

  defp post_schedules_request(body, id) do
    HTTPoison.post(url() <> "/tasks/#{id}/run_now", body, headers())
  end
end
