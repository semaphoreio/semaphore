defmodule PipelinesAPI.Router.TestResults.HistoryTest do
  use ExUnit.Case

  alias InternalApi.Superjerry.{
    ListFlakyHistoryResponse,
    ListDisruptionHistoryResponse,
    DisruptionRecord
  }

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

    {:ok, %{org: org, project: project}}
  end

  test "200 flaky_history returns {day,count} series", ctx do
    GrpcMock.stub(SuperjerryMock, :list_flaky_history, fn _req, _s ->
      %ListFlakyHistoryResponse{
        disruptions: [
          %DisruptionRecord{
            day: %Google.Protobuf.Timestamp{seconds: 1_700_000_000, nanos: 0},
            count: 5
          }
        ]
      }
    end)

    {status, body} = get("/projects/#{ctx.project.id}/test_results/flaky_history", ctx.org.id)

    assert status == 200
    assert [%{"count" => 5}] = body
  end

  test "200 disruption_history returns {day,count} series", ctx do
    GrpcMock.stub(SuperjerryMock, :list_disruption_history, fn _req, _s ->
      %ListDisruptionHistoryResponse{
        disruptions: [
          %DisruptionRecord{
            day: %Google.Protobuf.Timestamp{seconds: 1_700_000_000, nanos: 0},
            count: 7
          }
        ]
      }
    end)

    {status, body} = get("/projects/#{ctx.project.id}/test_results/disruption_history", ctx.org.id)

    assert status == 200
    assert [%{"count" => 7}] = body
  end

  test "404 for flaky_history when feature is disabled", ctx do
    Support.Stubs.Feature.disable_feature(ctx.org.id, :superjerry_tests)

    {status, _body} = get("/projects/#{ctx.project.id}/test_results/flaky_history", ctx.org.id, false)

    assert status == 404
  end

  test "404 for disruption_history when feature is disabled", ctx do
    Support.Stubs.Feature.disable_feature(ctx.org.id, :superjerry_tests)

    {status, _body} =
      get("/projects/#{ctx.project.id}/test_results/disruption_history", ctx.org.id, false)

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
