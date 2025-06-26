defmodule PipelinesAPI.Schedules.List.Test do
  use ExUnit.Case

  setup do
    Support.Stubs.grant_all_permissions()
    :ok
  end

  test "GET /schedules/:periodic_id - project ID mismatch" do
    org = Support.Stubs.Organization.create(name: "RT2", org_username: "rt2")
    user = Support.Stubs.User.create_default()
    project = Support.Stubs.Project.create(org, user)
    project_id = project.id

    _ = Support.Stubs.Scheduler.create(project_id, UUID.uuid4())
    params = %{"project_id" => project_id}
    assert {"Not Found", _} = list_schedules(params, 404, false)
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
    project_id = project.id

    _ = Support.Stubs.Scheduler.create(project_id, UUID.uuid4())
    params = %{"project_id" => project_id}
    assert {"Not Found", _} = list_schedules(params, 404, false)
  end

  test "GET /schedules/:periodic_id - returns valid description when server returns :OK response" do
    org = Support.Stubs.Organization.create_default()
    user = Support.Stubs.User.create_default()
    project = Support.Stubs.Project.create(org, user)
    project_id = project.id

    _ = Support.Stubs.Scheduler.create(project_id, UUID.uuid4())
    _ = Support.Stubs.Scheduler.create(project_id, UUID.uuid4())
    _ = Support.Stubs.Scheduler.create(project_id, UUID.uuid4())

    params = %{"project_id" => project_id}
    assert {schedules, headers} = list_schedules(params, 200)

    schedules
    |> Enum.map(fn schedule ->
      assert_schedule_description_valid(schedule)
    end)

    assert params["project_id"] |> expected_headers() |> headers_contain(headers)
  end

  defp assert_schedule_description_valid(schedule) do
    assert {:ok, _} = schedule["id"] |> UUID.info()
    assert schedule["name"] == "Scheduler"
    assert {:ok, _} = schedule["project_id"] |> UUID.info()
    assert schedule["branch"] == "master"
    assert schedule["at"] == "* * * * *"
    assert schedule["pipeline_file"] == ".semaphore/semaphore.yml"
    assert {:ok, _} = schedule["requester_id"] |> UUID.info()
    assert schedule["updated_at"] != ""
  end

  def list_schedules(parms, expected_status_code, decode \\ true) do
    {:ok, response} = list(parms)
    %{:body => body, :status_code => status_code, headers: headers} = response
    assert status_code == expected_status_code

    if decode do
      {Poison.decode!(body), headers}
    else
      {body, headers}
    end
  end

  defp headers_contain(list, headers) do
    Enum.map(list, fn value ->
      assert Enum.find(headers, nil, fn x -> x == value end) != nil
    end)
  end

  defp expected_headers(project_id) do
    [
      {"link", "#{link(project_id)}; rel=\"first\", #{link(project_id)}; rel=\"last\""},
      {"page-number", "1"},
      {"per-page", "30"},
      {"total", "3"},
      {"total-pages", "1"}
    ]
  end

  defp link(project_id) do
    "<http://localhost:4004/api/#{api_version()}/schedules?page=1&project_id=#{project_id}>"
  end

  defp api_version(), do: System.get_env("API_VERSION")

  def url, do: "localhost:4004"

  def headers() do
    [
      {"Content-type", "application/json"},
      {"x-semaphore-user-id", Support.Stubs.User.default_user_id()},
      {"x-semaphore-org-id", Support.Stubs.Organization.default_org_id()}
    ]
  end

  defp list(params),
    do: HTTPoison.get(url() <> "/schedules?" <> Plug.Conn.Query.encode(params), headers())
end
