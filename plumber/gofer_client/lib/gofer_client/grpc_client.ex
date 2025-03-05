defmodule GoferClient.GrpcClient do
  @moduledoc """
  Module is grpc client for Gofer service. It accepts proto message request, calls
  appropriate rpc method with this request as a parameter and returns server's
  repsonse in form of a proto message.
  """

  alias InternalApi.Gofer.Switch
  alias Util.Metrics
  alias LogTee, as: LT

  require Logger

  defp url(), do: System.get_env("INTERNAL_API_URL_GOFER")
  defp opts(), do: [{:timeout, Application.get_env(:gofer_client, :gofer_grpc_timeout)}]

  # Create

  def create_switch({:ok, :switch_not_defined}), do: {:ok, :switch_not_defined}
  def create_switch({:ok, create_request}) do
    result =  Wormhole.capture(__MODULE__, :create_, [create_request], stacktrace: true, timeout: 2_345)
    case result do
      {:ok, result} -> result
      error -> error
    end
  end
  def create_switch(error), do: error

  def create_(create_request) do
    Logger.info("Creating with request: #{inspect(create_request)}")
    {:ok, channel} = GRPC.Stub.connect(url())
    Metrics.benchmark("Ppl.gofer_client.grpc_client", "create", fn ->
      response = channel
      |> Switch.Stub.create(create_request, opts())

      Logger.info("Response: #{inspect(response)}")

      response
      |> is_ok?("create")
    end)
  end

  # PipelineDone

  def pipeline_done({:ok, :switch_not_defined}), do: {:ok, :switch_not_defined}
  def pipeline_done({:ok, request}) do
    result =  Wormhole.capture(__MODULE__, :pipeline_done_, [request], stacktrace: true)
    case result do
      {:ok, result} -> result
      error -> error
    end
  end
  def pipeline_done(error), do: error

  def pipeline_done_(request) do
    Logger.info("Pipeline done with request: #{inspect(request)}")
    {:ok, channel} = GRPC.Stub.connect(url())
    Metrics.benchmark("Ppl.gofer_client.grpc_client", "pipeline_done", fn ->
      response = channel
      |> Switch.Stub.pipeline_done(request, opts())
      |> is_ok?("pipeline_done")

      Logger.info("Response: #{inspect(response)}")
      response
      |> is_ok?("pipeline_done")
    end)
  end

  # Utility

  defp is_ok?(response = {:ok, _rsp}, _method), do: response
  defp is_ok?({:error, error}, rpc_method) do
    error |> LT.warn("Gofer service responded to #{rpc_method} request with: ")
    {:error, {:grpc_error, error}}
  end
end
