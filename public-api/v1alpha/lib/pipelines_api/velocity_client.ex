defmodule PipelinesAPI.VelocityClient do
  @moduledoc "Communication with the Velocity PipelineMetricsService over gRPC."

  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.VelocityClient.{RequestFormatter, GrpcClient, ResponseFormatter}

  @spec list_pipeline_performance_metrics(map()) :: {:ok, map()} | {:error, any()}
  def list_pipeline_performance_metrics(params) do
    Metrics.benchmark("PipelinesAPI.velocity_client", ["performance"], fn ->
      params
      |> RequestFormatter.form_performance_request()
      |> GrpcClient.list_pipeline_performance_metrics()
      |> ResponseFormatter.process_performance_response()
    end)
  end

  @spec list_pipeline_reliability_metrics(map()) :: {:ok, map()} | {:error, any()}
  def list_pipeline_reliability_metrics(params) do
    Metrics.benchmark("PipelinesAPI.velocity_client", ["reliability"], fn ->
      params
      |> RequestFormatter.form_reliability_request()
      |> GrpcClient.list_pipeline_reliability_metrics()
      |> ResponseFormatter.process_reliability_response()
    end)
  end

  @spec list_pipeline_frequency_metrics(map()) :: {:ok, map()} | {:error, any()}
  def list_pipeline_frequency_metrics(params) do
    Metrics.benchmark("PipelinesAPI.velocity_client", ["frequency"], fn ->
      params
      |> RequestFormatter.form_frequency_request()
      |> GrpcClient.list_pipeline_frequency_metrics()
      |> ResponseFormatter.process_frequency_response()
    end)
  end
end
