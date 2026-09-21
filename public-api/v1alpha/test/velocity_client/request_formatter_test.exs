defmodule PipelinesAPI.VelocityClient.RequestFormatterTest do
  use ExUnit.Case, async: true

  alias PipelinesAPI.VelocityClient.RequestFormatter, as: RF
  alias InternalApi.Velocity.ListPipelinePerformanceMetricsRequest

  test "maps params; pipeline_file required; aggregate string -> enum; dates -> Timestamp" do
    assert {:ok, %ListPipelinePerformanceMetricsRequest{} = req} =
             RF.form_performance_request(%{
               "project_id" => "p",
               "pipeline_file" => ".semaphore/semaphore.yml",
               "branch" => "main",
               "aggregate" => "range",
               "from" => "2026-01-01",
               "to" => "2026-01-31"
             })

    assert req.project_id == "p"
    assert req.pipeline_file_name == ".semaphore/semaphore.yml"
    assert req.branch_name == "main"
    assert req.aggregate == 0
    assert req.from_date.seconds > 0 and req.to_date.seconds > 0
  end

  test "missing pipeline_file is a user error" do
    assert {:error, {:user, _}} = RF.form_performance_request(%{"project_id" => "p"})
  end

  test "aggregate defaults to DAILY (1)" do
    assert {:ok, %ListPipelinePerformanceMetricsRequest{aggregate: 1}} =
             RF.form_performance_request(%{"project_id" => "p", "pipeline_file" => "f"})
  end

  test "form_reliability_request accepts same params" do
    alias InternalApi.Velocity.ListPipelineReliabilityMetricsRequest

    assert {:ok, %ListPipelineReliabilityMetricsRequest{pipeline_file_name: "f"}} =
             RF.form_reliability_request(%{"project_id" => "p", "pipeline_file" => "f"})
  end

  test "form_frequency_request accepts same params" do
    alias InternalApi.Velocity.ListPipelineFrequencyMetricsRequest

    assert {:ok, %ListPipelineFrequencyMetricsRequest{pipeline_file_name: "f"}} =
             RF.form_frequency_request(%{"project_id" => "p", "pipeline_file" => "f"})
  end
end
