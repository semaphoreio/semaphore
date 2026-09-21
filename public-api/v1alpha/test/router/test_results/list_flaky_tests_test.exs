defmodule PipelinesAPI.Router.TestResults.ListFlakyTestsTest do
  use ExUnit.Case

  alias InternalApi.Superjerry.{ListFlakyTestsResponse, Flaky}

  @default_user_id "user-1"

  setup do
    Support.Stubs.reset()
    Support.Stubs.grant_all_permissions()
    Cachex.clear(:project_api_cache)

    org = Support.Stubs.Organization.create_default()
    user = Support.Stubs.User.create_default()
    project = Support.Stubs.Project.create(org, user)

    Support.Stubs.Feature.set_org_defaults(org.id)
    Support.Stubs.Feature.enable_feature(org.id, :superjerry_tests)

    GrpcMock.stub(SuperjerryMock, :list_flaky_tests, fn _req, _s ->
      %ListFlakyTestsResponse{
        flaky_tests: [
          %Flaky{
            project_id: project.id,
            test_id: "t1",
            test_name: "spec",
            test_group: "",
            test_runner: "",
            test_file: "",
            test_suite: "",
            pass_rate: 80,
            labels: [],
            disruptions_count: 0,
            latest_disruption_hash: "",
            latest_disruption_run_id: "",
            resolved: false,
            scheduled: false,
            ticket_url: "",
            age: 0,
            total_count: 0
          }
        ],
        total_rows: 1,
        total_pages: 1
      }
    end)

    {:ok, %{org: org, project: project}}
  end

  test "200 lists flaky tests for an authorized project", ctx do
    {status, body} =
      get("/projects/#{ctx.project.id}/test_results/flaky_tests?page=1&page_size=20", ctx.org.id)

    assert status == 200
    assert [%{"test_id" => "t1", "test_name" => "spec"}] = body
  end

  test "404 when project belongs to a different org (cross-org isolation)", ctx do
    other_org = Support.Stubs.Organization.create(name: "RT2", org_username: "rt2")
    other_project = Support.Stubs.Project.create(other_org, %{id: UUID.uuid4()})

    Support.Stubs.Feature.set_org_defaults(other_org.id)
    Support.Stubs.Feature.enable_feature(other_org.id, :superjerry_tests)

    # Request uses the default org header — project belongs to other_org, so cross-org gate fires
    {status, body} =
      get("/projects/#{other_project.id}/test_results/flaky_tests", ctx.org.id, false)

    assert status == 404
    assert body == "Not Found"
  end

  test "404 when caller lacks project.view", ctx do
    GrpcMock.stub(RBACMock, :list_user_permissions, fn _, _ ->
      InternalApi.RBAC.ListUserPermissionsResponse.new(
        permissions: Support.Stubs.all_permissions_except("project.view")
      )
    end)

    {status, body} =
      get("/projects/#{ctx.project.id}/test_results/flaky_tests", ctx.org.id, false)

    assert status == 404
    assert body == "Not Found"
  end

  test "404 when feature flag is disabled", ctx do
    Support.Stubs.Feature.disable_feature(ctx.org.id, :superjerry_tests)

    {status, body} =
      get("/projects/#{ctx.project.id}/test_results/flaky_tests", ctx.org.id, false)

    assert status == 404
    assert body == "Feature is not enabled for your organization"
  end

  defp get(path, org_id, decode? \\ true) do
    url = "localhost:4004#{path}"

    headers = [
      {"Content-type", "application/json"},
      {"x-semaphore-user-id", @default_user_id},
      {"x-semaphore-org-id", org_id}
    ]

    {:ok, response} = HTTPoison.get(url, headers)
    %{body: body, status_code: status_code} = response

    body = if decode?, do: Poison.decode!(body), else: body
    {status_code, body}
  end
end
