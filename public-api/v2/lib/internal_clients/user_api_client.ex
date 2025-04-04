defmodule InternalClients.UserApi do
  @moduledoc """
    Module is used for communication with user API service over gRPC.
  """

  alias InternalApi.User.DescribeManyRequest
  alias InternalApi.User.UserService.Stub
  alias PublicAPI.Util.{Metrics, ToTuple}

  defp url(), do: System.get_env("USER_API_URL")

  @wormhole_timeout Application.compile_env(:public_api, :grpc_timeout, [])

  def describe_many(user_ids) do
    Metrics.benchmark(__MODULE__, ["describe_many"], fn ->
      request = %DescribeManyRequest{
        user_ids: user_ids
      }

      case Wormhole.capture(
             __MODULE__,
             :call_user_api,
             [request],
             stacktrace: true,
             skip_log: true,
             timeout_ms: @wormhole_timeout,
             ok_tuple: true
           ) do
        {:ok, result} ->
          {:ok, result.users}

        {:error, reason} ->
          reason |> LogTee.error("Error describing many users: #{inspect(reason)}")
          ToTuple.internal_error("Internal error")
      end
    end)
  end

  def call_user_api(request) do
    {:ok, channel} = url() |> GRPC.Stub.connect()
    Stub.describe_many(channel, request, timeout: @wormhole_timeout)
  end
end
