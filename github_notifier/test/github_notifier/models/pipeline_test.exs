defmodule GithubNotifier.Models.PipelineTest do
  use ExUnit.Case

  alias GithubNotifier.Models.Pipeline

  setup do
    :ok
  end

  describe ".find" do
    test "when the response is successfull => returns a pipeline" do
      response = Support.Factories.pipeline_describe_response()
      GrpcMock.stub(PipelineMock, :describe, response)

      assert Pipeline.find("1") == %Pipeline{
               id: response.pipeline.ppl_id,
               state: response.pipeline.state,
               result: response.pipeline.result,
               sha: "1234567",
               project_id: "1",
               workflow_id: "3",
               hook_id: "3",
               created_at: 0,
               yaml_file_path: ".semaphore/semaphore.yml",
               name: "Pipeline",
               triggered_by: :HOOK,
               ppl_triggered_by: :WORKFLOW,
               workflow_rerun_of: "",
               scheduler_task_id: "",
               blocks: [
                 %{
                   id: "1",
                   name: "Block 1",
                   state: :RUNNING,
                   result: :PASSED
                 },
                 %{
                   id: "2",
                   name: "Block 2",
                   state: :RUNNING,
                   result: :PASSED
                 },
                 %{
                   id: "3",
                   name: "Block 3",
                   state: :RUNNING,
                   result: :PASSED
                 }
               ]
             }
    end

    test "when the response is bad => returns nil" do
      response = Support.Factories.pipeline_describe_response(code: :bad)
      GrpcMock.stub(PipelineMock, :describe, response)

      assert Pipeline.find("1") == nil
    end

    test "carries the workflow triggerer details" do
      response =
        Support.Factories.pipeline_describe_response(
          triggered_by: :SCHEDULE,
          ppl_triggered_by: :PARTIAL_RE_RUN,
          workflow_rerun_of: "prev-wf-id"
        )

      GrpcMock.stub(PipelineMock, :describe, response)

      pipeline = Pipeline.find("1")

      assert pipeline.triggered_by == :SCHEDULE
      assert pipeline.ppl_triggered_by == :PARTIAL_RE_RUN
      assert pipeline.workflow_rerun_of == "prev-wf-id"
    end

    test "when the triggerer is missing => falls back to hook defaults" do
      response = Support.Factories.pipeline_describe_response()
      response = put_in(response.pipeline.triggerer, nil)

      GrpcMock.stub(PipelineMock, :describe, response)

      pipeline = Pipeline.find("1")

      assert pipeline.triggered_by == :HOOK
      assert pipeline.ppl_triggered_by == :WORKFLOW
      assert pipeline.workflow_rerun_of == ""
    end
  end
end
