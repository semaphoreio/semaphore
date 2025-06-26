defmodule PipelinesAPI.Schedules.Describe.Test do
  use ExUnit.Case

  setup do
    Support.Stubs.grant_all_permissions()
    :ok
  end

  test "GET /schedules/:periodic_id - project ID mismatch" do
    org = Support.Stubs.Organization.create(name: "RT2", org_username: "rt2")
    user = Support.Stubs.User.create_default()
    project = Support.Stubs.Project.create(org, user)
    scheduler = Support.Stubs.Scheduler.create(project.id, user.id)

    assert "Not Found" = describe_schedule(scheduler.id, 404, false)
  end

  test "GET /schedules/:periodic_id - no permission" do
    GrpcMock.stub(RBACMock, :list_user_permissions, fn _, _ ->
      InternalApi.RBAC.ListUserPermissionsResponse.new(
        permissions: Support.Stubs.all_permissions_except("project.scheduler.view")
      )
    end)

    org = Support.Stubs.Organization.create_default()
    user = Support.Stubs.User.create_default()
    project = Support.Stubs.Project.create(org, user)
    scheduler = Support.Stubs.Scheduler.create(project.id, user.id)
    assert "Not Found" = describe_schedule(scheduler.id, 404, false)
  end

  test "GET /schedules/:periodic_id - returns valid description when server returns :OK response" do
    org = Support.Stubs.Organization.create_default()
    user = Support.Stubs.User.create_default()
    project = Support.Stubs.Project.create(org, user)
    scheduler = Support.Stubs.Scheduler.create(project.id, user.id, name: "First periodic")
    hook = %{id: UUID.uuid4(), project_id: project.id, branch_id: UUID.uuid4()}
    workflow = Support.Stubs.Workflow.create(hook, user.id, organization_id: org.id)
    {user_id, workflow_id} = {user.id, workflow.id}

    _ = Support.Stubs.Scheduler.create_trigger(scheduler, workflow_id, user_id)
    _ = Support.Stubs.Scheduler.create_trigger(scheduler, workflow_id, user_id)

    assert %{"schedule" => schedule, "triggers" => triggers} =
             describe_schedule(scheduler.id, 200)

    assert_schedule_description_valid(schedule)
    triggers |> Enum.at(0) |> assert_trigger_description_valid()
    triggers |> Enum.at(1) |> assert_trigger_description_valid()
  end

  test "GET /schedules/:periodic_name returns 400" do
    assert "schedule identifier should be a UUID" =
             describe_schedule("not-a-valid-scheduler-id", 400)
  end

  defp assert_schedule_description_valid(schedule) do
    assert {:ok, _} = schedule["id"] |> UUID.info()
    assert schedule["name"] == "First periodic"
    assert {:ok, _} = schedule["project_id"] |> UUID.info()
    assert schedule["branch"] == "master"
    assert schedule["at"] == "* * * * *"
    assert schedule["pipeline_file"] == ".semaphore/semaphore.yml"
    assert {:ok, _} = schedule["requester_id"] |> UUID.info()
    assert schedule["updated_at"] != ""
  end

  defp assert_trigger_description_valid(trigger) do
    assert trigger["triggered_at"] != ""
    assert {:ok, _} = trigger["project_id"] |> UUID.info()
    assert trigger["branch"] == "master"
    assert trigger["pipeline_file"] == ".semaphore/semaphore.yml"
    assert trigger["scheduling_status"] == "passed"
    assert {:ok, _} = trigger["scheduled_workflow_id"] |> UUID.info()
    assert trigger["scheduled_at"] != ""
    assert trigger["error_description"] == ""
  end

  def describe_schedule(identifier, expected_status_code, decode \\ true) do
    {:ok, response} = get_description(identifier)
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

  defp get_description(identifier),
    do: HTTPoison.get(url() <> "/schedules/" <> identifier, headers())
end
