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
               result_reason: response.pipeline.result_reason,
               queue_type: :IMPLICIT,
               sha: "1234567",
               project_id: "1",
               workflow_id: "3",
               hook_id: "3",
               created_at: 0,
               yaml_file_path: ".semaphore/semaphore.yml",
               name: "Pipeline",
               triggered_by: :HOOK,
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

    test "carries the workflow trigger and the task that started it" do
      response =
        Support.Factories.pipeline_describe_response(
          triggered_by: :SCHEDULE,
          wf_triggerer_id: "task-1"
        )

      GrpcMock.stub(PipelineMock, :describe, response)

      pipeline = Pipeline.find("1")

      assert pipeline.triggered_by == :SCHEDULE
      assert pipeline.scheduler_task_id == "task-1"
    end

    test "carries the reason a run ended, which decides whether it reports at all" do
      response =
        Support.Factories.pipeline_describe_response(
          state: :DONE,
          result: :CANCELED,
          result_reason: :STRATEGY
        )

      GrpcMock.stub(PipelineMock, :describe, response)

      pipeline = Pipeline.find("1")

      assert pipeline.result == :CANCELED
      assert pipeline.result_reason == :STRATEGY
    end

    test "carries the queue type, and leaves it nil when there is no queue yet" do
      response = Support.Factories.pipeline_describe_response(queue_type: :USER_GENERATED)
      GrpcMock.stub(PipelineMock, :describe, response)
      assert Pipeline.find("1").queue_type == :USER_GENERATED

      response = put_in(response.pipeline.queue, nil)
      GrpcMock.stub(PipelineMock, :describe, response)
      assert Pipeline.find("1").queue_type == nil
    end

    test "when the triggerer is missing => falls back to hook defaults" do
      response = Support.Factories.pipeline_describe_response()
      response = put_in(response.pipeline.triggerer, nil)

      GrpcMock.stub(PipelineMock, :describe, response)

      pipeline = Pipeline.find("1")

      assert pipeline.triggered_by == :HOOK
      assert pipeline.scheduler_task_id == ""
    end
  end
end
