defmodule PipelinesAPI.WorkflowClient.Test do
  use ExUnit.Case

  alias PipelinesAPI.WorkflowClient

  setup do
    Support.Stubs.reset()
  end

  test "workflow client schedule and get valid response" do
    response = WorkflowClient.schedule(schedule_params())
    assert {:ok, schedule_response} = response
    assert %{workflow_id: wf_id, pipeline_id: ppl_id} = schedule_response
    assert {:ok, _} = UUID.info(ppl_id)
    assert {:ok, _} = UUID.info(wf_id)
  end

  test "workflow client schedule - limit exceeded" do
    GrpcMock.stub(WorkflowMock, :schedule, fn _, _stream ->
      InternalApi.PlumberWF.ScheduleResponse.new(
        status:
          InternalApi.Status.new(
            code: Google.Rpc.Code.value(:RESOURCE_EXHAUSTED),
            message: "No more workflows for you."
          )
      )
    end)

    response = WorkflowClient.schedule(schedule_params())
    assert {:error, {:user, message}} = response
    assert message == "No more workflows for you."
  end

  test "workflow client schedule - refused if project deletion was requested" do
    GrpcMock.stub(WorkflowMock, :schedule, fn _, _stream ->
      InternalApi.PlumberWF.ScheduleResponse.new(
        status:
          InternalApi.Status.new(
            code: Google.Rpc.Code.value(:FAILED_PRECONDITION),
            message: "Project was deleted."
          )
      )
    end)

    assert {:error, {:user, message}} = WorkflowClient.schedule(schedule_params())
    assert message == "Project was deleted."
  end

  defp schedule_params() do
    %{
      "reference" => "refs/heads/main",
      "commit_sha" => "773d5c953bd68cc97efa81d2e014449336265fb4",
      "definition_file" => "semaphore.yml",
      "project_id" => UUID.uuid4(),
      "organization_id" => UUID.uuid4(),
      "requester_id" => UUID.uuid4(),
      "repository" => %{integration_type: :GITHUB_APP}
    }
  end
end
