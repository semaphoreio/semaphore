defmodule PipelinesAPI.Router.TestResults.FlakyTestDetailsTest do
  use ExUnit.Case

  alias InternalApi.Superjerry.{FlakyTestDetailsResponse, FlakyTestDetail}

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

    GrpcMock.stub(SuperjerryMock, :flaky_test_details, fn _req, _s ->
      %FlakyTestDetailsResponse{
        detail: %FlakyTestDetail{
          project_id: project.id,
          id: "t1",
          name: "spec",
          group: "",
          runner: "",
          file: "",
          labels: [],
          contexts: ["c"],
          pass_rates: [90.0],
          p95_durations: [1.0],
          impacts: [0.0],
          total_counts: [1],
          disruptions_count: [1],
          hashes: ["h"],
          available_contexts: ["c"],
          selected_context: "c"
        }
      }
    end)

    {:ok, %{org: org, project: project}}
  end

  test "200 returns reshaped per-context detail", ctx do
    {status, body} = get("/projects/#{ctx.project.id}/test_results/flaky_tests/t1", ctx.org.id)

    assert status == 200
    assert body["id"] == "t1"
    assert [%{"context" => "c", "pass_rate" => 90.0}] = body["contexts"]
  end

  test "404 when feature is disabled", ctx do
    Support.Stubs.Feature.disable_feature(ctx.org.id, :superjerry_tests)

    {status, _body} = get("/projects/#{ctx.project.id}/test_results/flaky_tests/t1", ctx.org.id, false)

    assert status == 404
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
