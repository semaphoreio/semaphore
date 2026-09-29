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
        # Note: With GRPC.Client.Supervisor managing connections (grpc >= 0.9),
        # we should NOT manually disconnect. The supervisor handles connection lifecycle.
        apply(stub, rpc, [channel, req, opts])

      err ->
        Logger.error("GRCP endpoint #{endpoint} is unrechable #{inspect(err)}")
        {:error, :unrechable}
    end
  end
end
