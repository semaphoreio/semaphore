defmodule GoferClient.GrpcClient do
  @moduledoc """
  Module is grpc client for Gofer service. It accepts proto message request, calls
  appropriate rpc method with this request as a parameter and returns server's
  repsonse in form of a proto message.
  """

  alias InternalApi.Gofer.Switch
  alias InternalApi.Gofer.DeploymentTargets
  alias Util.Metrics
  alias LogTee, as: LT

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
    {:ok, channel} = GRPC.Stub.connect(url())
    Metrics.benchmark("Ppl.gofer_client.grpc_client", "create", fn ->
      channel
      |> Switch.Stub.create(create_request, opts())
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
    {:ok, channel} = GRPC.Stub.connect(url())
    Metrics.benchmark("Ppl.gofer_client.grpc_client", "pipeline_done", fn ->
      channel
      |> Switch.Stub.pipeline_done(request, opts())
      |> is_ok?("pipeline_done")
    end)
  end

  # Verify Deployment Target Access

  def verify_deployment_target_access({:ok, verify_request}) do
    result = Wormhole.capture(__MODULE__, :verify_deployment_target_access_, [verify_request], stacktrace: true, timeout: 2_345)
    case result do
      {:ok, result} -> result
      error -> error
    end
  end
  def verify_deployment_target_access(error), do: error

  def verify_deployment_target_access_(verify_request) do
    {:ok, channel} = GRPC.Stub.connect(url())
    Metrics.benchmark("Ppl.gofer_client.grpc_client", "verify_deployment_target", fn ->
      channel
      |> DeploymentTargets.DeploymentTargets.Stub.verify(verify_request, opts())
      |> is_ok?("verify_deployment_target")
    end)
  end

  # Utility

  defp is_ok?(response = {:ok, _rsp}, _method), do: response
  defp is_ok?({:error, error}, rpc_method) do
    error |> LT.warn("Gofer service responded to #{rpc_method} request with: ")
    {:error, {:grpc_error, error}}
  end
end
