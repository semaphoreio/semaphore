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

  test "workflow client request formatter schedule - creates valid gRPC request when given valid params" do
    alias InternalApi.PlumberWF.TriggeredBy
    alias PipelinesAPI.WorkflowClient.WFRequestFormatter
    alias InternalApi.PlumberWF.ScheduleRequest.{ServiceType, EnvVar}

    params = schedule_params()

    assert {:ok, request} = WFRequestFormatter.form_schedule_request(params)
    assert request.service == ServiceType.value(:GIT_HUB)
    assert request.repo.branch_name == "main"
    assert request.repo.commit_sha == "773d5c953bd68cc97efa81d2e014449336265fb4"
    assert {:ok, _} = UUID.info(request.request_token)
    assert request.requester_id == params["requester_id"]
    assert request.definition_file == "semaphore.yml"
    assert request.organization_id == params["organization_id"]
    assert request.git_reference == "refs/heads/main"
    assert request.start_in_conceived_state == true
    assert request.triggered_by == TriggeredBy.value(:API)
    assert request.env_vars == [%EnvVar{name: "MY_PARAM", value: "my_value"}]
  end

  defp schedule_params() do
    %{
      "reference" => "refs/heads/main",
      "commit_sha" => "773d5c953bd68cc97efa81d2e014449336265fb4",
      "pipeline_file" => "semaphore.yml",
      "project_id" => UUID.uuid4(),
      "organization_id" => UUID.uuid4(),
      "requester_id" => UUID.uuid4(),
      "repository" => %{integration_type: :GITHUB_APP},
      "parameters" => %{"MY_PARAM" => "my_value"}
    }
  end
end
