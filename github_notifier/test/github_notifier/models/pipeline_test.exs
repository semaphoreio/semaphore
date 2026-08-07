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
  end
end
