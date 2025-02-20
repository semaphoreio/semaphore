defmodule PipelinesAPI.SecretClient.GrpcClient do
  @moduledoc """
  Module is used for making gRPC calls to SecretHub service.
  """

  alias PipelinesAPI.Util.Metrics

  alias InternalApi.Secrethub.{
    SecretService
  }

  alias PipelinesAPI.Util.Log
  alias PipelinesAPI.Util.ResponseValidation, as: Resp

  defp url(), do: System.get_env("SECRETHUB_GRPC_URL")
  defp opts(), do: [{:timeout, Application.get_env(:pipelines_api, :grpc_timeout)}]

  defp timeout(), do: Application.get_env(:pipelines_api, :grpc_timeout)

  # Schedule

  def key({:ok, key_request}) do
    result =
      Wormhole.capture(__MODULE__, :key_, [key_request],
        timeout: timeout(),
        stacktrace: true,
        skip_log: true
      )

    case result do
      {:ok, result} -> result
      {:error, reason} -> Log.internal_error(reason, "key")
    end
  end

  def key_(key_request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    Metrics.benchmark("PipelinesAPI.secret_client.grpc_client", ["key"], fn ->
      channel
      |> SecretService.Stub.get_key(key_request, opts())
      |> Resp.ok?("key")
    end)
  end

  def describe({:ok, describe_request}) do
    result =
      Wormhole.capture(__MODULE__, :describe_, [describe_request],
        timeout: timeout(),
        stacktrace: true,
        skip_log: true
      )

    case result do
      {:ok, result} -> result
      {:error, reason} -> Log.internal_error(reason, "describe")
    end
  end

  def describe(error), do: error

  def describe_(describe_request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    Metrics.benchmark("PipelinesAPI.secret_client.grpc_client", ["describe"], fn ->
      channel
      |> SecretService.Stub.describe(describe_request, opts())
      |> Resp.ok?("describe")
    end)
  end
end
