defmodule PipelinesAPI.GoferClient.GrpcClient do
  @moduledoc """
  Module is used for making gRPC calls to Gofer service.
  """

  alias PipelinesAPI.Util.Metrics
  alias InternalApi.Gofer.Switch
  alias PipelinesAPI.Util.Log
  alias PipelinesAPI.Util.ResponseValidation, as: Resp

  defp url(), do: System.get_env("GOFER_GRPC_URL")
  defp opts(), do: [{:timeout, Application.get_env(:pipelines_api, :grpc_timeout)}]

  # List

  def list({:ok, list_request}) do
    result =
      Wormhole.capture(__MODULE__, :list_, [list_request], stacktrace: true, skip_log: true)

    case result do
      {:ok, result} -> result
      {:error, reason} -> Log.internal_error(reason, "list")
    end
  end

  def list(error), do: error

  def list_(list_request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    Metrics.benchmark("PipelinesAPI.gofer_client.grpc_client", ["list"], fn ->
      channel
      |> Switch.Stub.list_trigger_events(list_request, opts())
      |> Resp.ok?("list")
    end)
  end

  # Trigger

  def trigger({:ok, trigger_request}) do
    result =
      Wormhole.capture(__MODULE__, :trigger_, [trigger_request], stacktrace: true, skip_log: true)

    case result do
      {:ok, result} -> result
      {:error, reason} -> Log.internal_error(reason, "trigger")
    end
  end

  def trigger(error), do: error

  def trigger_(trigger_request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    Metrics.benchmark("PipelinesAPI.gofer_client.grpc_client", ["trigger"], fn ->
      channel
      |> Switch.Stub.trigger(trigger_request, opts())
      |> Resp.ok?("trigger")
    end)
  end
end
