defmodule PipelinesAPI.Schedules.Delete.Test do
  use ExUnit.Case

  setup do
    Support.Stubs.grant_all_permissions()
    :ok
  end

  test "DELETE /schedules/:periodic_id - project ID mismatch" do
    org = Support.Stubs.Organization.create(name: "RT2", org_username: "rt2")
    user = Support.Stubs.User.create_default()
    project = Support.Stubs.Project.create(org, user)
    scheduler = Support.Stubs.Scheduler.create(project.id, user.id)
    assert "Not Found" = delete_schedule(scheduler.id, 404, false)
  end

  test "DELETE /schedules/:periodic_id - no permission" do
    GrpcMock.stub(RBACMock, :list_user_permissions, fn _, _ ->
      InternalApi.RBAC.ListUserPermissionsResponse.new(
        permissions: Support.Stubs.all_permissions_except("project.scheduler.manage")
      )
    end)

    org = Support.Stubs.Organization.create_default()
    user = Support.Stubs.User.create_default()
    project = Support.Stubs.Project.create(org, user)
    scheduler = Support.Stubs.Scheduler.create(project.id, user.id)
    assert "Not Found" = delete_schedule(scheduler.id, 404, false)
  end

  test "DELETE /schedules/:periodic_id - successful when server returns :OK response" do
    org = Support.Stubs.Organization.create_default()
    user = Support.Stubs.User.create_default()
    project = Support.Stubs.Project.create(org, user)
    scheduler = Support.Stubs.Scheduler.create(project.id, user.id)
    assert {:ok, message} = delete_schedule(scheduler.id, 200)
    assert message == "Schedule successfully deleted."
  end

  test "DELETE /schedules/:periodic_name returns 400" do
    assert {:ok, message} = delete_schedule("not-a-valid-periodic-name", 400)
    assert message == "schedule identifier should be a UUID"
  end

  def delete_schedule(identifier, expected_status_code, decode \\ true) do
    {:ok, response} = delete(identifier)
    %{:body => body, :status_code => status_code} = response
    if(status_code != expected_status_code, do: IO.puts("Response body: #{inspect(body)}"))
    assert status_code == expected_status_code

    if decode do
      Poison.decode(body)
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

  defp delete(identifier), do: HTTPoison.delete(url() <> "/schedules/" <> identifier, headers())
end
