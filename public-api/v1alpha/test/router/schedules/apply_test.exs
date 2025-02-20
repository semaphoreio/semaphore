defmodule PipelinesAPI.Schedules.Apply.Test do
  use ExUnit.Case

  setup do
    Support.Stubs.init()
    Support.Stubs.grant_all_permissions()
    :ok
  end

  test "POST /schedules - project ID mismatch" do
    org = Support.Stubs.Organization.create(name: "RT2", org_username: "rt2")
    user = Support.Stubs.User.create_default()
    Support.Stubs.Project.create(org, user, name: "pipelines-test-repo-auto-call_II")

    def =
      "apiVersion: v1.0\nkind: Periodic\nmetadata:\n  name: First periodic\n" <>
        "spec:\n  project: pipelines-test-repo-auto-call_II\n  branch: master\n" <>
        "  at: \"*/5 * * * *\"\n  pipeline_file: .semaphore/semaphore.yml\n"

    params = %{"yml_definition" => def}
    assert "\"Project not found\"" = post_schedule(params, 400, false)
  end

  test "POST /schedules - no permission" do
    GrpcMock.stub(RBACMock, :list_user_permissions, fn _, _ ->
      InternalApi.RBAC.ListUserPermissionsResponse.new(
        permissions: Support.Stubs.all_permissions_except("project.scheduler.manage")
      )
    end)

    org = Support.Stubs.Organization.create_default()
    user = Support.Stubs.User.create_default()
    Support.Stubs.Project.create(org, user, name: "pipelines-test-repo-auto-call_II")

    def =
      "apiVersion: v1.0\nkind: Periodic\nmetadata:\n  name: First periodic\n" <>
        "spec:\n  project: pipelines-test-repo-auto-call_II\n  branch: master\n" <>
        "  at: \"*/5 * * * *\"\n  pipeline_file: .semaphore/semaphore.yml\n"

    params = %{"yml_definition" => def}
    assert "Not Found" = post_schedule(params, 404, false)
  end

  test "POST /schedules - success when creating new schedule and PeriodicSch returns :OK" do
    org = Support.Stubs.Organization.create_default()
    user = Support.Stubs.User.create_default()
    Support.Stubs.Project.create(org, user, name: "pipelines-test-repo-auto-call_II")

    def =
      "apiVersion: v1.0\nkind: Periodic\nmetadata:\n  name: First periodic\n" <>
        "spec:\n  project: pipelines-test-repo-auto-call_II\n  branch: master\n" <>
        "  at: \"*/5 * * * *\"\n  pipeline_file: .semaphore/semaphore.yml\n"

    params = %{"yml_definition" => def}

    assert id = post_schedule(params, 200)
    assert {:ok, _} = UUID.info(id)
  end

  test "POST /schedules - success when updating existing schedule and PeriodicSch returns :OK" do
    org = Support.Stubs.Organization.create_default()
    user = Support.Stubs.User.create_default()
    Support.Stubs.Project.create(org, user, name: "pipelines-test-repo-auto-call_II")

    def =
      "apiVersion: v1.0\nkind: Periodic\nmetadata:\n  name: First periodic\n" <>
        "  id: #{UUID.uuid4()}\n" <>
        "spec:\n  project: pipelines-test-repo-auto-call_II\n  branch: master\n" <>
        "  at: \"*/5 * * * *\"\n  pipeline_file: .semaphore/semaphore.yml\n"

    params = %{"yml_definition" => def}

    assert id = post_schedule(params, 200)
    assert {:ok, _} = UUID.info(id)
  end

  def post_schedule(args, expected_status_code, decode \\ true)
      when is_map(args) do
    {:ok, response} = args |> Poison.encode!() |> post_schedules_request()
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

  defp post_schedules_request(body) do
    HTTPoison.post(url() <> "/schedules", body, headers())
  end
end
