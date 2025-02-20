defmodule PipelinesAPI.WorkflowClient.Test do
  use ExUnit.Case

  alias PipelinesAPI.WorkflowClient
  alias Test.GitHub.Credentials

  setup do
    Support.Stubs.reset()
  end

  test "workflow client schedule and get valid response" do
    response = WorkflowClient.schedule(schedule_params())
    assert {:ok, schedule_response} = response
    assert %{wf_id: wf_id, ppl_id: ppl_id} = schedule_response
    assert {:ok, _} = UUID.info(ppl_id)
    assert {:ok, _} = UUID.info(wf_id)
  end

  test "workflow client schedule - empty request_token" do
    params = schedule_params() |> Map.replace!("ppl_request_token", "")
    assert {:error, {:user, message}} = WorkflowClient.schedule(params)
    assert message.code == :INVALID_ARGUMENT
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

    response = WorkflowClient.schedule(schedule_params_same_branch())
    assert {:error, {:user, status}} = response
    assert status.code == :RESOURCE_EXHAUSTED
    assert status.message == "No more workflows for you."
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

    assert {:error, {:user, status}} = WorkflowClient.schedule(schedule_params())
    assert status.code == :FAILED_PRECONDITION
    assert status.message == "Project was deleted."
  end

  defp schedule_params_same_branch() do
    same_branch_params = %{
      "branch_id" => "123",
      "project_id" => "123",
      "service" => "local",
      "repo_name" => "8_sleeping"
    }

    schedule_params()
    |> Map.merge(same_branch_params)
  end

  defp schedule_params() do
    %{
      "owner" => "renderedtext",
      "repo_name" => "pipelines-test-repo-auto-call",
      "service" => "git_hub",
      "ppl_request_token" => UUID.uuid4(),
      "branch_id" => UUID.uuid4(),
      "hook_id" => UUID.uuid4(),
      "requester_id" => UUID.uuid4(),
      "branch_name" => "10s-pipeline-run",
      "commit_sha" => "773d5c953bd68cc97efa81d2e014449336265fb4",
      "file_name" => "semaphore.yml",
      "working_dir" => ".semaphore",
      "snapshot_archive" => "123",
      "project_id" => UUID.uuid4(),
      "organization_id" => UUID.uuid4()
    }
    |> Map.merge(Credentials.string_keys())
  end
end
