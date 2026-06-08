defmodule PipelinesAPI.Router.InsightsTest do
  use ExUnit.Case

  alias InternalApi.Velocity.{
    ListPipelinePerformanceMetricsResponse,
    PerformanceMetric,
    ListPipelineReliabilityMetricsResponse,
    ReliabilityMetric,
    ListPipelineFrequencyMetricsResponse,
    FrequencyMetric
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
    Support.Stubs.Feature.enable_feature(org.id, :velocity)

    {:ok, %{org: org, project: project}}
  end

  test "200 performance returns all/passed/failed series", ctx do
    GrpcMock.stub(VelocityMock, :list_pipeline_performance_metrics, fn _r, _s ->
      %ListPipelinePerformanceMetricsResponse{
        all_metrics: [
          %PerformanceMetric{
            count: 4,
            mean_seconds: 40,
            median_seconds: 35,
            min_seconds: 10,
            max_seconds: 60,
            std_dev_seconds: 5,
            p95_seconds: 55
          }
        ],
        passed_metrics: [],
        failed_metrics: []
      }
    end)

    {status, body} =
      get(
        "/projects/#{ctx.project.id}/insights/performance?pipeline_file=.semaphore/semaphore.yml",
        ctx.org.id
      )

    assert status == 200
    assert [%{"count" => 4}] = body["all"]
    assert [] = body["passed"]
    assert [] = body["failed"]
  end

  test "400 when pipeline_file is missing", ctx do
    {status, _body} = get("/projects/#{ctx.project.id}/insights/performance", ctx.org.id, false)
    assert status == 400
  end

  test "200 reliability returns metrics series", ctx do
    GrpcMock.stub(VelocityMock, :list_pipeline_reliability_metrics, fn _r, _s ->
      %ListPipelineReliabilityMetricsResponse{
        metrics: [%ReliabilityMetric{all_count: 9, passed_count: 7, failed_count: 2}]
      }
    end)

    {status, body} =
      get(
        "/projects/#{ctx.project.id}/insights/reliability?pipeline_file=.semaphore/semaphore.yml",
        ctx.org.id
      )

    assert status == 200
    assert [%{"failed_count" => 2}] = body["metrics"]
  end

  test "200 frequency returns metrics series", ctx do
    GrpcMock.stub(VelocityMock, :list_pipeline_frequency_metrics, fn _r, _s ->
      %ListPipelineFrequencyMetricsResponse{
        metrics: [%FrequencyMetric{all_count: 11}]
      }
    end)

    {status, body} =
      get(
        "/projects/#{ctx.project.id}/insights/frequency?pipeline_file=.semaphore/semaphore.yml",
        ctx.org.id
      )

    assert status == 200
    assert [%{"all_count" => 11}] = body["metrics"]
  end

  test "404 when feature flag is disabled", ctx do
    Support.Stubs.Feature.disable_feature(ctx.org.id, :velocity)

    {status, body} =
      get(
        "/projects/#{ctx.project.id}/insights/performance?pipeline_file=f",
        ctx.org.id,
        false
      )

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
      get(
        "/projects/#{ctx.project.id}/insights/performance?pipeline_file=f",
        ctx.org.id,
        false
      )

    assert status == 404
    assert body == "Not Found"
  end

  test "404 when project belongs to a different org (cross-org isolation)", ctx do
    other_org = Support.Stubs.Organization.create(name: "RT2", org_username: "rt2")
    other_project = Support.Stubs.Project.create(other_org, %{id: UUID.uuid4()})

    Support.Stubs.Feature.set_org_defaults(other_org.id)
    Support.Stubs.Feature.enable_feature(other_org.id, :velocity)

    {status, body} =
      get(
        "/projects/#{other_project.id}/insights/performance?pipeline_file=f",
        ctx.org.id,
        false
      )

    assert status == 404
    assert body == "Not Found"
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
