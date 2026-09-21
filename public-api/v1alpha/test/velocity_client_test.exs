defmodule PipelinesAPI.VelocityClientTest do
  use ExUnit.Case

  alias PipelinesAPI.VelocityClient
  alias InternalApi.Velocity.{ListPipelinePerformanceMetricsResponse, PerformanceMetric}

  setup do
    Support.Stubs.reset()
    System.put_env("INTERNAL_API_URL_VELOCITY", "127.0.0.1:50052")
    :ok
  end

  test "list_pipeline_performance_metrics returns reshaped all/passed/failed series" do
    GrpcMock.stub(VelocityMock, :list_pipeline_performance_metrics, fn _req, _stream ->
      %ListPipelinePerformanceMetricsResponse{
        all_metrics: [
          %PerformanceMetric{
            from_date: nil,
            to_date: nil,
            count: 10,
            mean_seconds: 100,
            median_seconds: 0,
            min_seconds: 0,
            max_seconds: 0,
            std_dev_seconds: 0,
            p95_seconds: 200
          }
        ],
        passed_metrics: [],
        failed_metrics: []
      }
    end)

    assert {:ok, %{all: [%{count: 10, mean_seconds: 100}], passed: [], failed: []}} =
             VelocityClient.list_pipeline_performance_metrics(%{
               "project_id" => "p",
               "pipeline_file" => ".semaphore/semaphore.yml",
               "aggregate" => "daily"
             })
  end

  test "list_pipeline_reliability_metrics returns %{metrics}" do
    alias InternalApi.Velocity.{ListPipelineReliabilityMetricsResponse, ReliabilityMetric}

    GrpcMock.stub(VelocityMock, :list_pipeline_reliability_metrics, fn _req, _stream ->
      %ListPipelineReliabilityMetricsResponse{
        metrics: [
          %ReliabilityMetric{
            from_date: nil,
            to_date: nil,
            all_count: 1,
            passed_count: 1,
            failed_count: 0
          }
        ]
      }
    end)

    assert {:ok, %{metrics: [%{all_count: 1}]}} =
             VelocityClient.list_pipeline_reliability_metrics(%{
               "project_id" => "p",
               "pipeline_file" => "f"
             })
  end

  test "list_pipeline_frequency_metrics returns %{metrics}" do
    alias InternalApi.Velocity.{ListPipelineFrequencyMetricsResponse, FrequencyMetric}

    GrpcMock.stub(VelocityMock, :list_pipeline_frequency_metrics, fn _req, _stream ->
      %ListPipelineFrequencyMetricsResponse{
        metrics: [
          %FrequencyMetric{
            from_date: nil,
            to_date: nil,
            all_count: 2
          }
        ]
      }
    end)

    assert {:ok, %{metrics: [%{all_count: 2}]}} =
             VelocityClient.list_pipeline_frequency_metrics(%{
               "project_id" => "p",
               "pipeline_file" => "f"
             })
  end
end
