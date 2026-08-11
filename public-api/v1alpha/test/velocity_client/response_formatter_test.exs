defmodule PipelinesAPI.VelocityClient.ResponseFormatterTest do
  use ExUnit.Case, async: true

  alias PipelinesAPI.VelocityClient.ResponseFormatter, as: RF

  alias InternalApi.Velocity.{
    ListPipelinePerformanceMetricsResponse,
    PerformanceMetric,
    ListPipelineReliabilityMetricsResponse,
    ReliabilityMetric,
    ListPipelineFrequencyMetricsResponse,
    FrequencyMetric
  }

  test "performance -> %{all,passed,failed} with iso dates" do
    ts = %Google.Protobuf.Timestamp{seconds: 1_700_000_000, nanos: 0}

    resp =
      {:ok,
       %ListPipelinePerformanceMetricsResponse{
         all_metrics: [
           %PerformanceMetric{
             from_date: ts,
             to_date: ts,
             count: 5,
             mean_seconds: 50,
             median_seconds: 0,
             min_seconds: 0,
             max_seconds: 0,
             std_dev_seconds: 0,
             p95_seconds: 90
           }
         ],
         passed_metrics: [],
         failed_metrics: []
       }}

    assert {:ok, %{all: [m], passed: [], failed: []}} = RF.process_performance_response(resp)
    assert m.count == 5 and m.mean_seconds == 50 and m.p95_seconds == 90
    assert is_binary(m.from_date)
  end

  test "reliability -> %{metrics}" do
    resp =
      {:ok,
       %ListPipelineReliabilityMetricsResponse{
         metrics: [
           %ReliabilityMetric{
             from_date: nil,
             to_date: nil,
             all_count: 10,
             passed_count: 8,
             failed_count: 2
           }
         ]
       }}

    assert {:ok, %{metrics: [%{all_count: 10, passed_count: 8, failed_count: 2}]}} =
             RF.process_reliability_response(resp)
  end

  test "frequency -> %{metrics}" do
    resp =
      {:ok,
       %ListPipelineFrequencyMetricsResponse{
         metrics: [
           %FrequencyMetric{
             from_date: nil,
             to_date: nil,
             all_count: 3
           }
         ]
       }}

    assert {:ok, %{metrics: [%{all_count: 3}]}} = RF.process_frequency_response(resp)
  end

  test "errors pass through" do
    assert {:error, {:internal, "x"}} =
             RF.process_performance_response({:error, {:internal, "x"}})
  end
end
