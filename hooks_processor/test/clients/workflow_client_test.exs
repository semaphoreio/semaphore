defmodule HooksProcessor.Clients.WorkflowClient.Test do
  use ExUnit.Case

  alias InternalApi.PlumberWF.ScheduleResponse
  alias HooksProcessor.Clients.WorkflowClient
  alias Support.BitbucketHooks

  @grpc_port 50_045

  setup_all do
    GRPC.Server.start(WorkflowServiceMock, @grpc_port)

    on_exit(fn ->
      GRPC.Server.stop(WorkflowServiceMock)

      Test.Helpers.wait_until_stopped(WorkflowServiceMock)
    end)

    {:ok, %{}}
  end

  setup do
    webhook = %{
      id: UUID.uuid4(),
      project_id: UUID.uuid4(),
      request: BitbucketHooks.push_new_branch_with_commits(),
      state: "processing",
      provider: "bitbucket",
      repository_id: UUID.uuid4(),
      organization_id: UUID.uuid4(),
      received_at: DateTime.utc_now()
    }

    data = %{
      branch_id: UUID.uuid4(),
      yml_file: ".semaphore/semaphore.yml",
      requester_id: UUID.uuid4(),
      branch_name: "master",
      owner: "renderedtext",
      repo_name: "test",
      commit_sha: "sha_1",
      provider: "bitbucket"
    }

    {:ok, %{webhook: webhook, data: data}}
  end

  test "schedule() correctly timeouts if workflow service takes to long to respond", ctx do
    use_mock_workflow_service()

    WorkflowServiceMock
    |> GrpcMock.expect(:schedule, fn _req, _ ->
      :timer.sleep(15_500)
      %ScheduleResponse{}
    end)

    assert {:error, message} = WorkflowClient.schedule_workflow(ctx.webhook, ctx.data)
    assert {:grpc_error, %GRPC.RPCError{message: "Deadline expired", status: 4}} = message

    GrpcMock.verify!(WorkflowServiceMock)
  end

  test "schedule request is correctly formed and OK response is correctly parsed", ctx do
    use_mock_workflow_service()

    WorkflowServiceMock
    |> GrpcMock.expect(:schedule, fn req, _ ->
      assert_request_valid(req, ctx)

      %ScheduleResponse{wf_id: UUID.uuid4(), ppl_id: UUID.uuid4(), status: %{code: :OK}}
    end)

    assert {:ok, %{wf_id: wf_id, ppl_id: ppl_id}} = WorkflowClient.schedule_workflow(ctx.webhook, ctx.data)

    assert {:ok, _} = UUID.info(wf_id)
    assert {:ok, _} = UUID.info(ppl_id)

    GrpcMock.verify!(WorkflowServiceMock)
  end

  def assert_request_valid(req, %{webhook: webhook, data: data}) do
    assert req.requester_id == data.requester_id
    assert req.organization_id == webhook.organization_id
    assert req.project_id == webhook.project_id
    assert req.branch_id == data.branch_id
    assert req.hook_id == webhook.id
    assert req.request_token == webhook.id
    assert req.triggered_by == :HOOK
    assert req.service == :BITBUCKET
    assert req.definition_file == data.yml_file
    assert req.label == data.branch_name
    assert req.repo.owner == data.owner
    assert req.repo.repo_name == data.repo_name
    assert req.repo.branch_name == data.branch_name
    assert req.repo.commit_sha == data.commit_sha
    assert req.repo.repository_id == webhook.repository_id
  end

  test "returns error when workflow service responds with anything but OK", ctx do
    use_mock_workflow_service()

    WorkflowServiceMock
    |> GrpcMock.expect(:schedule, fn _req, _ ->
      %ScheduleResponse{status: %{code: :INVALID_ARGUMENT, message: "Error"}}
    end)

    assert {:error, status} = WorkflowClient.schedule_workflow(ctx.webhook, ctx.data)
    assert status == %InternalApi.Status{code: :INVALID_ARGUMENT, message: "Error"}

    GrpcMock.verify!(WorkflowServiceMock)
  end

  defp use_mock_workflow_service,
    do: Application.put_env(:hooks_processor, :plumber_grpc_url, "localhost:#{inspect(@grpc_port)}")
end
