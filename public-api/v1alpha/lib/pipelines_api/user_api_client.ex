defmodule PipelinesAPI.UserApiClient do
  @moduledoc """
    Module is used for communication with user API service over gRPC.
  """

  alias InternalApi.User.DescribeManyRequest
  alias InternalApi.User.DescribeByEmailRequest
  alias InternalApi.User.UserService.Stub
  alias PipelinesAPI.Util.{Metrics, ToTuple}
  alias Util.Proto

  defp url(), do: System.get_env("USER_API_URL")

  @wormhole_timeout Application.compile_env(:pipelines_api, :grpc_timeout, [])
  @not_found_grpc_status_code 5

  def describe_many(user_ids) do
    Metrics.benchmark(__MODULE__, ["describe_many"], fn ->
      request = DescribeManyRequest.new(user_ids: user_ids)

      case Wormhole.capture(
             __MODULE__,
             :call_api,
             [request, :describe_many],
             stacktrace: true,
             skip_log: true,
             timeout_ms: @wormhole_timeout,
             ok_tuple: true
           ) do
        {:ok, result} ->
          Proto.to_map(result)

        {:error, reason} ->
          reason |> LogTee.error("Error describing many users: #{inspect(reason)}")
          ToTuple.internal_error("Internal error")
      end
    end)
  end

  def describe_by_email(email) do
    Metrics.benchmark(__MODULE__, ["describe_by_email"], fn ->
      request = DescribeByEmailRequest.new(email: email)

      case Wormhole.capture(
             __MODULE__,
             :call_api,
             [request, :describe_by_email],
             stacktrace: true,
             skip_log: true,
             timeout_ms: @wormhole_timeout,
             ok_tuple: true
           ) do
        {:ok, result} ->
          Proto.to_map(result)

        {:error, {:error, %{status: @not_found_grpc_status_code}}} ->
          {:error, :not_found}

        {:error, reason} ->
          Logger.error("Error describing user by email: #{inspect(reason)}")
          ToTuple.internal_error("Internal error")
      end
    end)
  end

  def call_api(request, method) do
    {:ok, channel} = url() |> GRPC.Stub.connect()
    apply(Stub, method, [channel, request, [timeout: @wormhole_timeout]])
  end
end
