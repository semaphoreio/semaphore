defmodule GithubNotifier.Models.PipelineSummaryTest do
  use ExUnit.Case
  require Logger

  alias GithubNotifier.Models.PipelineSummary

  alias InternalApi.Velocity

  describe ".find" do
    test "returns ok tuple when everything is 👌" do
      pipeline_summary =
        Velocity.PipelineSummary.new(
          pipeline_id: "81f1b92c-8c02-4328-9c05-e64a1d303b27",
          summary:
            Velocity.Summary.new(
              total: 100,
              passed: 20,
              skipped: 20,
              error: 20,
              failed: 20,
              disabled: 20,
              duration: 1_400_000
            )
        )

      response =
        Velocity.ListPipelineSummariesResponse.new(pipeline_summaries: [pipeline_summary])

      GrpcMock.stub(VelocityHubMock, :list_pipeline_summaries, response)

      assert %{
               disabled: 20,
               duration: 1_400_000,
               error: 20,
               failed: 20,
               passed: 20,
               pipeline_id: "81f1b92c-8c02-4328-9c05-e64a1d303b27",
               skipped: 20,
               total: 100
             } == PipelineSummary.find(pipeline_summary.pipeline_id)
    end

    test "returns error when there is no summary for pipeline" do
      response = Velocity.ListPipelineSummariesResponse.new(pipeline_summaries: [])
      GrpcMock.stub(VelocityHubMock, :list_pipeline_summaries, response)

      assert nil == PipelineSummary.find("81f1b92c-8c02-4328-9c05-e64a1d303b27")
    end
  end

  describe ".is_failed?" do
    test "returns true when there are failed specs" do
      assert true ==
               PipelineSummary.is_failed?(
                 Velocity.Summary.new(
                   passed: 20,
                   error: 0,
                   failed: 20
                 )
               )

      assert true ==
               PipelineSummary.is_failed?(
                 Velocity.Summary.new(
                   passed: 20,
                   error: 20,
                   failed: 0
                 )
               )

      assert true ==
               PipelineSummary.is_failed?(
                 Velocity.Summary.new(
                   passed: 20,
                   error: 20,
                   failed: 20
                 )
               )
    end

    test "returns false when there are no failed specs" do
      assert false ==
               PipelineSummary.is_failed?(Velocity.Summary.new(passed: 20))

      assert false ==
               PipelineSummary.is_failed?(Velocity.Summary.new(passed: 20, failed: 0))

      assert false ==
               PipelineSummary.is_failed?(Velocity.Summary.new(passed: 20, error: 0))
    end
  end

  describe ".is_passed?" do
    test "returns true when there are no failed specs" do
      assert true ==
               PipelineSummary.is_passed?(
                 Velocity.Summary.new(
                   total: 20,
                   passed: 20,
                   error: 0,
                   failed: 0
                 )
               )
    end

    test "returns false when there are failed specs" do
      assert false ==
               PipelineSummary.is_passed?(
                 Velocity.Summary.new(
                   passed: 20,
                   failed: 20
                 )
               )

      assert false ==
               PipelineSummary.is_passed?(
                 Velocity.Summary.new(
                   passed: 20,
                   error: 20
                 )
               )
    end

    test "returns false when there are no specs" do
      assert false ==
               PipelineSummary.is_passed?(Velocity.Summary.new(total: 0))

      assert false ==
               PipelineSummary.is_passed?(Velocity.Summary.new(passed: 20, total: 0))
    end
  end
end
