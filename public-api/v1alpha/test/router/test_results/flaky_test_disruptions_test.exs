defmodule PipelinesAPI.Router.TestResults.FlakyTestDisruptionsTest do
  use ExUnit.Case

  alias InternalApi.Superjerry.{FlakyTestDisruptionsResponse, FlakyTestDisruption}

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

  test "200 lists disruptions for an authorized project", ctx do
    GrpcMock.stub(SuperjerryMock, :flaky_test_disruptions, fn _req, _s ->
      %FlakyTestDisruptionsResponse{
        disruptions: [
          %FlakyTestDisruption{context: "c", hash: "h", run_id: "r", total_count: 0}
        ],
        total_rows: 1,
        total_pages: 1
      }
    end)

    {status, body} =
      get(
        "/projects/#{ctx.project.id}/test_results/flaky_tests/t1/disruptions?page=1&page_size=10",
        ctx.org.id
      )

    assert status == 200
    assert [%{"context" => "c", "hash" => "h", "run_id" => "r"}] = body
  end

  test "404 when feature is disabled", ctx do
    Support.Stubs.Feature.disable_feature(ctx.org.id, :superjerry_tests)

    {status, _body} =
      get(
        "/projects/#{ctx.project.id}/test_results/flaky_tests/t1/disruptions",
        ctx.org.id,
        false
      )

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
