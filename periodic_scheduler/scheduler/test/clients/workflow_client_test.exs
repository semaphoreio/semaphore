defmodule Scheduler.Clients.WorkflowClient.Test do
  use ExUnit.Case

  alias Scheduler.Clients.WorkflowClient

  @grpc_port 50_054
  setup_all do
    GRPC.Server.start(Test.MockWorkflowService, @grpc_port)

    on_exit(fn ->
      GRPC.Server.stop(Test.MockWorkflowService)
    end)

    {:ok, %{}}
  end

  test "returns {:ok, wf_id} when workflow service responds with OK" do
    use_mock_workflow_service()
    mock_workflow_service_response("ok")

    assert {:ok, wf_id} = WorkflowClient.schedule(%{triggered_by: :SCHEDULE})
    assert {:ok, _} = UUID.info(wf_id)
  end

  test "returns {:error, status} when workflow service responds with anything but OK" do
    use_mock_workflow_service()
    mock_workflow_service_response("invalid_argument")

    assert {:error, status} = WorkflowClient.schedule(%{triggered_by: :SCHEDULE})
    assert status == %{code: :INVALID_ARGUMENT, message: "Error"}

    mock_workflow_service_response("resource_exhausted")

    assert {:error, status} = WorkflowClient.schedule(%{triggered_by: :SCHEDULE})
    assert status == %{code: :RESOURCE_EXHAUSTED, message: "Too many pipelines in the queue."}
  end

  defp use_mock_workflow_service(),
    do:
      Application.put_env(
        :scheduler,
        :workflow_api_grpc_endpoint,
        "localhost:#{inspect(@grpc_port)}"
      )

  def mock_workflow_service_response(value),
    do: Application.put_env(:scheduler, :mock_workflow_service_response, value)
end
