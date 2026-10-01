defmodule GithubNotifier.Models.PipelineSummaryTest do
  use ExUnit.Case

  alias GithubNotifier.Models.PipelineSummary

  alias InternalApi.Velocity

  describe ".find" do
    test "returns ok tuple when everything is 👌" do
      pipeline_summary =
        struct(Velocity.PipelineSummary,
          pipeline_id: "81f1b92c-8c02-4328-9c05-e64a1d303b27",
          summary:
            struct(Velocity.Summary,
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
        struct(Velocity.ListPipelineSummariesResponse, pipeline_summaries: [pipeline_summary])

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
      response = struct(Velocity.ListPipelineSummariesResponse, pipeline_summaries: [])
      GrpcMock.stub(VelocityHubMock, :list_pipeline_summaries, response)

      assert nil == PipelineSummary.find("81f1b92c-8c02-4328-9c05-e64a1d303b27")
    end
  end

  describe ".failed?" do
    test "returns true when there are failed specs" do
      assert true ==
               PipelineSummary.failed?(
                 struct(Velocity.Summary,
                   passed: 20,
                   error: 0,
                   failed: 20
                 )
               )

      assert true ==
               PipelineSummary.failed?(
                 struct(Velocity.Summary,
                   passed: 20,
                   error: 20,
                   failed: 0
                 )
               )

      assert true ==
               PipelineSummary.failed?(
                 struct(Velocity.Summary,
                   passed: 20,
                   error: 20,
                   failed: 20
                 )
               )
    end

    test "returns false when there are no failed specs" do
      assert false ==
               PipelineSummary.failed?(struct(Velocity.Summary, passed: 20))

      assert false ==
               PipelineSummary.failed?(struct(Velocity.Summary, passed: 20, failed: 0))

      assert false ==
               PipelineSummary.failed?(struct(Velocity.Summary, passed: 20, error: 0))
    end
  end

  describe ".passed?" do
    test "returns true when there are no failed specs" do
      assert true ==
               PipelineSummary.passed?(
                 struct(Velocity.Summary,
                   total: 20,
                   passed: 20,
                   error: 0,
                   failed: 0
                 )
               )
    end

    test "returns false when there are failed specs" do
      assert false ==
               PipelineSummary.passed?(
                 struct(Velocity.Summary,
                   passed: 20,
                   failed: 20
                 )
               )

      assert false ==
               PipelineSummary.passed?(
                 struct(Velocity.Summary,
                   passed: 20,
                   error: 20
                 )
               )
    end

    test "returns false when there are no specs" do
      assert false ==
               PipelineSummary.passed?(struct(Velocity.Summary, total: 0))

      assert false ==
               PipelineSummary.passed?(struct(Velocity.Summary, passed: 20, total: 0))
    end
  end
end
