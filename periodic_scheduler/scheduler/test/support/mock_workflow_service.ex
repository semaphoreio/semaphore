defmodule Test.MockWorkflowService do
  @moduledoc """
    Mocks WorkflowService GRPC server.
  """

  use GRPC.Server, service: InternalApi.PlumberWF.WorkflowService.Service

  alias InternalApi.PlumberWF.ScheduleResponse
  alias Util.Proto

  def schedule(%{triggered_by: :SCHEDULE}, _stream) do
    response_type = Application.get_env(:scheduler, :mock_workflow_service_response)
    respond(response_type)
  end

  def schedule(%{triggered_by: :MANUAL_RUN}, _stream) do
    response_type = Application.get_env(:scheduler, :mock_workflow_service_response)
    respond(response_type)
  end

  defp respond("ok") do
    %{status: %{code: :OK}}
    |> Map.merge(%{wf_id: UUID.uuid4()})
    |> Proto.deep_new!(ScheduleResponse)
  end

  defp respond("invalid_argument") do
    %{status: %{code: :INVALID_ARGUMENT, message: "Error"}}
    |> Proto.deep_new!(ScheduleResponse)
  end

  defp respond("resource_exhausted") do
    %{status: %{code: :RESOURCE_EXHAUSTED, message: "Too many pipelines in the queue."}}
    |> Proto.deep_new!(ScheduleResponse)
  end

  defp respond("timeout") do
    :timer.sleep(5_000)
    Proto.deep_new!(%{}, ScheduleResponse)
  end
end
