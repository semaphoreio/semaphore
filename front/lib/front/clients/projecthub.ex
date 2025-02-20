defmodule Front.Clients.Projecthub do
  @moduledoc """
  Client for communication with the Velocity service.
  """
  require Logger
  alias Util.Proto

  alias InternalApi.Projecthub.{
    DescribeRequest,
    DescribeResponse,
    ProjectService.Stub
  }

  @type rpc_response(response_type) :: {:ok, response_type} | {:error, GRPC.RPCError.t()}

  @spec describe(DescribeRequest.t() | Map.t()) :: rpc_response(DescribeResponse.t())
  def describe(request) when is_struct(request, DescribeRequest) do
    Watchman.benchmark("projecthub.describe.duration", fn ->
      grpc_send(connect(), :describe, request)
      |> case do
        {:ok, response} ->
          {:ok, response}

        {:error, error} ->
          {:error, error}
      end
    end)
  end

  def describe(request), do: Proto.deep_new!(DescribeRequest, request) |> describe()

  defp connect, do: GRPC.Stub.connect(Application.fetch_env!(:front, :projecthub_grpc_endpoint))

  defp grpc_send(error = {:error, _}, _, _), do: error

  defp grpc_send({:ok, channel}, method, request),
    do: apply(Stub, method, [channel, request]),
    after: GRPC.Stub.disconnect(channel)
end
