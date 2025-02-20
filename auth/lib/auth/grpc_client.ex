defmodule Auth.GrpcClient do
  require Logger

  def call(stub, endpoint, rpc, req, opts) do
    result = Wormhole.capture(fn -> do_call(stub, endpoint, rpc, req, opts) end)

    case result do
      {:ok, res} -> res
      {:error, err} -> {:error, err}
    end
  end

  defp do_call(stub, endpoint, rpc, req, opts) do
    case GRPC.Stub.connect(endpoint) do
      {:ok, channel} ->
        response = apply(stub, rpc, [channel, req, opts])
        GRPC.Stub.disconnect(channel)
        response

      err ->
        Logger.error("GRCP endpoint #{endpoint} is unrechable #{inspect(err)}")
        {:error, :unrechable}
    end
  end
end
