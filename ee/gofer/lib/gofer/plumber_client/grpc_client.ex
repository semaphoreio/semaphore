defmodule Gofer.PlumberClient.GrpcClient do
  @moduledoc """
  Module is grpc client for Plumber service. It accepts proto message request, calls
  appropriate rpc method with this request as a parameter and returns server's
  repsonse in form of a proto message.
  """

  alias InternalApi.Plumber.PipelineService
  alias Util.Metrics
  alias LogTee, as: LT

  defp url(), do: Application.get_env(:gofer, :plumber_grpc_url)
  defp opts(), do: [{:timeout, Application.get_env(:gofer, :plumber_grpc_timeout)}]

  # ScheduleExtension

  def schedule_extension(request) do
    result = Wormhole.capture(__MODULE__, :schedule_extension_, [request], stacktrace: true)

    case result do
      {:ok, result} -> result
      error -> error
    end
  end

  def schedule_extension_(request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    Metrics.benchmark("Gofer.plumber_client", "schedule_extension", fn ->
      channel
      |> PipelineService.Stub.schedule_extension(request, opts())
      |> is_ok?("schedule_extension")
    end)
  end

  # Describe

  def describe(describe_request) do
    result = Wormhole.capture(__MODULE__, :describe_, [describe_request], stacktrace: true)

    case result do
      {:ok, result} -> result
      error -> error
    end
  end

  def describe_(describe_request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    Metrics.benchmark("Gofer.plumber_client", "describe", fn ->
      channel
      |> PipelineService.Stub.describe(describe_request, opts())
      |> is_ok?("describe")
    end)
  end

  # Utility

  defp is_ok?(response = {:ok, _rsp}, _method), do: response

  defp is_ok?({:error, error}, rpc_method) do
    error |> LT.warn("Plumber service responded to #{rpc_method} request with: ")
    {:error, {:grpc_error, error}}
  end
end
