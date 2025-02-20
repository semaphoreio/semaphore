defmodule Scheduler.Clients.WorkflowClient do
  @moduledoc """
   Module is used for communication with Plumber Workflows service over gRPC.
  """

  alias Util.{Metrics, Proto, ToTuple}
  alias InternalApi.PlumberWF.{WorkflowService, ScheduleRequest}
  alias LogTee, as: LT

  defp url(), do: Application.get_env(:scheduler, :workflow_api_grpc_endpoint)

  @timeout 15_000

  def schedule(params) do
    Metrics.benchmark("PeriodicSch.WorkflowClient", ["schedule"], fn ->
      params
      |> Proto.deep_new(ScheduleRequest)
      |> schedule_grpc()
      |> process_schedule_response()
    end)
  end

  def schedule_grpc({:ok, schedule_request}) do
    result =
      Wormhole.capture(__MODULE__, :schedule_grpc_, [schedule_request],
        stacktrace: true,
        skip_log: true,
        timeout: @timeout
      )

    case result do
      {:ok, result} -> result
      error -> error
    end
  end

  def schedule_grpc(error), do: error

  def schedule_grpc_(schedule_request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    channel
    |> WorkflowService.Stub.schedule(schedule_request)
    |> is_ok?("schedule")
  end

  def process_schedule_response({:ok, schedule_response}) do
    with true <- is_map(schedule_response),
         {:ok, status} <- Map.fetch(schedule_response, :status),
         {:code, :OK} <- {:code, Map.get(status, :code)},
         {:ok, wf_id} <- Map.fetch(schedule_response, :wf_id) do
      {:ok, wf_id}
    else
      {:code, _} -> when_status_code_not_ok(schedule_response)
      _ -> log_invalid_response(schedule_response, "schedule")
    end
  end

  def process_schedule_response(error), do: error

  defp when_status_code_not_ok(schedule_response) do
    schedule_response
    |> Map.get(:status)
    |> Map.take(~w(code message)a)
    |> ToTuple.error()
  end

  # Utility

  defp is_ok?(response = {:ok, _rsp}, _method), do: response

  defp is_ok?({:error, error}, rpc_method) do
    error |> LT.warn("WorkflowPB service responded to #{rpc_method} request with: ")
    {:error, {:grpc_error, error}}
  end

  defp log_invalid_response(response, rpc_method) do
    response
    |> LT.error("WorkflowPB service responded to #{rpc_method} with :ok and invalid data:")

    {:error, {:grpc_error, response}}
  end
end
