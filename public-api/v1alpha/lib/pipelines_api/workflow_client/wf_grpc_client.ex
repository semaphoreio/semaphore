defmodule PipelinesAPI.WorkflowClient.WFGrpcClient do
  @moduledoc """
  Module is used for making gRPC calls to Workflow service.
  """

  alias PipelinesAPI.Util.ResponseValidation, as: Resp
  alias PipelinesAPI.Util.Log

  alias InternalApi.PlumberWF.{
    WorkflowService
  }

  alias PipelinesAPI.Util.Metrics

  defp url(), do: System.get_env("PPL_GRPC_URL")
  defp opts(), do: [{:timeout, Application.get_env(:pipelines_api, :grpc_timeout)}]

  def schedule({:ok, schedule_request}) do
    result =
      Wormhole.capture(__MODULE__, :schedule_, [schedule_request],
        stacktrace: true,
        skip_log: true
      )

    case result do
      {:ok, result} -> result
      {:error, reason} -> Log.internal_error(reason, "wf schedule")
    end
  end

  def schedule(error), do: error

  def schedule_(schedule_request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    Metrics.benchmark("PipelinesAPI.router", ["schedule_snapshot"], fn ->
      channel
      |> WorkflowService.Stub.schedule(schedule_request, opts())
      |> Resp.ok?("schedule")
    end)
  end

  # Terminate

  def terminate({:ok, terminate_request}) do
    result = Wormhole.capture(__MODULE__, :terminate_, [terminate_request], stacktrace: true)

    case result do
      {:ok, result} -> result
      {:error, reason} -> Log.internal_error(reason, "wf terminate")
    end
  end

  def terminate(error), do: error

  def terminate_(terminate_request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    Metrics.benchmark("PipelinesAPI.router", ["wf terminate"], fn ->
      channel
      |> WorkflowService.Stub.terminate(terminate_request, opts())
      |> Resp.ok?("terminate")
    end)
  end

  # Reschedule

  def reschedule({:ok, reschedule_request}) do
    result =
      Wormhole.capture(__MODULE__, :reschedule_, [reschedule_request],
        stacktrace: true,
        skip_log: true
      )

    case result do
      {:ok, result} -> result
      {:error, reason} -> Log.internal_error(reason, "wf reschedule")
    end
  end

  def reschedule(error), do: error

  def reschedule_(reschedule_request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    Metrics.benchmark("PipelinesAPI.router", ["reschedule"], fn ->
      channel
      |> WorkflowService.Stub.reschedule(reschedule_request, opts())
      |> Resp.ok?("schedule")
    end)
  end

  # Describe

  def describe({:ok, describe_request}) do
    result = Wormhole.capture(__MODULE__, :describe_, [describe_request], stacktrace: true)

    case result do
      {:ok, result} -> result
      {:error, reason} -> Log.internal_error(reason, "wf_describe")
    end
  end

  def describe(error), do: error

  def describe_(describe_request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    Metrics.benchmark("PipelinesAPI.ppl_client.grpc_client", ["describe"], fn ->
      channel
      |> WorkflowService.Stub.describe(describe_request, opts())
      |> Resp.ok?("describe")
    end)
  end
end
