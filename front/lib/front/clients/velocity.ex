defmodule Front.Clients.Velocity do
  @moduledoc """
  Client for communication with the Velocity service.
  """
  require Logger

  alias Util.Proto

  alias InternalApi.Velocity.{
    ChangeDashboardItemNotesRequest,
    CreateDashboardItemRequest,
    CreateFlakyTestsFilterRequest,
    CreateMetricsDashboardRequest,
    DeleteDashboardItemRequest,
    DeleteMetricsDashboardRequest,
    DescribeDashboardItemRequest,
    DescribeProjectPerformanceRequest,
    DescribeProjectPerformanceResponse,
    DescribeProjectSettingsRequest,
    InitializeFlakyTestsFiltersRequest,
    ListFlakyTestsFiltersRequest,
    ListJobSummariesRequest,
    ListJobSummariesResponse,
    ListMetricsDashboardsRequest,
    ListPipelineFrequencyMetricsRequest,
    ListPipelineFrequencyMetricsResponse,
    ListPipelinePerformanceMetricsRequest,
    ListPipelinePerformanceMetricsResponse,
    ListPipelineReliabilityMetricsRequest,
    ListPipelineReliabilityMetricsResponse,
    ListPipelineSummariesRequest,
    ListPipelineSummariesResponse,
    OrganizationHealthRequest,
    RemoveFlakyTestsFilterRequest,
    UpdateDashboardItemRequest,
    UpdateFlakyTestsFilterRequest,
    UpdateMetricsDashboardRequest,
    UpdateProjectSettingsRequest
  }

  alias InternalApi.Velocity

  alias Util

  @type rpc_request(response_type) :: response_type | Map.t()
  @type rpc_response(response_type) :: {:ok, response_type} | {:error, GRPC.RPCError.t()}

  @spec list_pipeline_performance_metrics(
          request :: rpc_request(ListPipelinePerformanceMetricsRequest.t())
        ) ::
          rpc_response(ListPipelinePerformanceMetricsResponse.t())
  def list_pipeline_performance_metrics(request),
    do:
      request
      |> decorate(ListPipelinePerformanceMetricsRequest)
      |> grpc_call(:list_pipeline_performance_metrics)

  @spec list_pipeline_reliability_metrics(rpc_request(ListPipelineReliabilityMetricsRequest.t())) ::
          rpc_response(ListPipelineReliabilityMetricsResponse.t())
  def list_pipeline_reliability_metrics(request),
    do:
      request
      |> decorate(ListPipelineReliabilityMetricsRequest)
      |> grpc_call(:list_pipeline_reliability_metrics)

  @spec list_pipeline_frequency_metrics(rpc_request(ListPipelineFrequencyMetricsRequest.t())) ::
          rpc_response(ListPipelineFrequencyMetricsResponse.t())
  def list_pipeline_frequency_metrics(request),
    do:
      request
      |> decorate(ListPipelineFrequencyMetricsRequest)
      |> grpc_call(:list_pipeline_frequency_metrics)

  @spec list_pipeline_summaries(rpc_request(ListPipelineSummariesRequest.t())) ::
          rpc_response(ListPipelineSummariesResponse.t())
  def list_pipeline_summaries(request),
    do:
      request
      |> decorate(ListPipelineSummariesRequest)
      |> grpc_call(:list_pipeline_summaries)

  @spec list_job_summaries(rpc_request(ListJobSummariesRequest.t())) ::
          rpc_response(ListJobSummariesResponse.t())
  def list_job_summaries(request),
    do:
      request
      |> decorate(ListJobSummariesRequest)
      |> grpc_call(:list_job_summaries)

  @spec describe_project_performance(rpc_request(DescribeProjectPerformanceRequest.t())) ::
          rpc_response(DescribeProjectPerformanceResponse.t())
  def describe_project_performance(request),
    do:
      request
      |> decorate(DescribeProjectPerformanceRequest)
      |> grpc_call(:describe_project_performance)

  def describe_project_settings(request),
    do:
      request
      |> decorate(DescribeProjectSettingsRequest)
      |> grpc_call(:describe_project_settings)

  def update_insights_project_settings(request),
    do:
      request
      |> decorate(UpdateProjectSettingsRequest)
      |> grpc_call(:update_project_settings)

  def describe_metrics_dashboard(request),
    do:
      request
      |> decorate(DescribeMetricsDashboardRequest)
      |> grpc_call(:describe_metrics_dashboard)

  def list_metrics_dashboards(request),
    do:
      request
      |> decorate(ListMetricsDashboardsRequest)
      |> grpc_call(:list_metrics_dashboards)

  def create_metrics_dashboard(request),
    do:
      request
      |> decorate(CreateMetricsDashboardRequest)
      |> grpc_call(:create_metrics_dashboard)

  def delete_metrics_dashboard(request),
    do:
      request
      |> decorate(DeleteMetricsDashboardRequest)
      |> grpc_call(:delete_metrics_dashboard)

  def update_metrics_dashboard(request),
    do:
      request
      |> decorate(UpdateMetricsDashboardRequest)
      |> grpc_call(:update_metrics_dashboard)

  def describe_metrics_dashboard_item(request),
    do:
      request
      |> decorate(DescribeDashboardItemRequest)
      |> grpc_call(:describe_dashboard_item)

  def create_metrics_dashboard_item(request),
    do:
      request
      |> decorate(CreateDashboardItemRequest)
      |> grpc_call(:create_dashboard_item)

  def update_metrics_dashboard_item(request),
    do:
      request
      |> decorate(UpdateDashboardItemRequest)
      |> grpc_call(:update_dashboard_item)

  def delete_metrics_dashboard_item(request),
    do:
      request
      |> decorate(DeleteDashboardItemRequest)
      |> grpc_call(:delete_dashboard_item)

  def change_metrics_dashboard_item_description(request),
    do:
      request
      |> decorate(ChangeDashboardItemNotesRequest)
      |> grpc_call(:change_dashboard_item_notes)

  def fetch_organization_health(request),
    do:
      request
      |> decorate(OrganizationHealthRequest)
      |> grpc_call(:fetch_organization_health)

  def list_flaky_tests_filters(request),
    do:
      request
      |> decorate(ListFlakyTestsFiltersRequest)
      |> grpc_call(:list_flaky_tests_filters)

  def initialize_flaky_tests_filters(request),
    do:
      request
      |> decorate(InitializeFlakyTestsFiltersRequest)
      |> grpc_call(:initialize_flaky_tests_filters)

  def create_flaky_tests_filter(request),
    do:
      request
      |> decorate(CreateFlakyTestsFilterRequest)
      |> grpc_call(:create_flaky_tests_filter)

  def remove_flaky_tests_filter(request),
    do:
      request
      |> decorate(RemoveFlakyTestsFilterRequest)
      |> grpc_call(:remove_flaky_tests_filter)

  def update_flaky_tests_filter(request),
    do:
      request
      |> decorate(UpdateFlakyTestsFilterRequest)
      |> grpc_call(:update_flaky_tests_filter)

  defp decorate(request, schema) when is_struct(request, schema) do
    request
  end

  defp decorate(request, schema) do
    Proto.deep_new!(request, schema)
  end

  defp grpc_call(request, action) do
    if System.get_env("SKIP_VELOCITY") == "true" do
      {:error, :not_implemented}
    else
      _grpc_call(request, action)
    end
  end

  defp _grpc_call(request, action) do
    Watchman.benchmark("velocity.#{action}.duration", fn ->
      channel()
      |> call_grpc(Velocity.PipelineMetricsService.Stub, action, request, metadata(), timeout())
      |> tap(fn
        {:ok, _} -> Watchman.increment("velocity.#{action}.success")
        {:error, _} -> Watchman.increment("velocity.#{action}.failure")
      end)
    end)
  end

  defp call_grpc(error = {:error, err}, _, _, _, _, _) do
    Logger.error("""
    Unexpected error when connecting to Velocity: #{inspect(err)}
    """)

    error
  end

  defp call_grpc({:ok, channel}, module, function_name, request, metadata, timeout) do
    apply(module, function_name, [channel, request, [metadata: metadata, timeout: timeout]])
  end

  defp channel do
    Application.fetch_env!(:front, :velocity_grpc_endpoint)
    |> GRPC.Stub.connect()
  end

  defp timeout do
    4000
  end

  defp metadata do
    nil
  end
end
