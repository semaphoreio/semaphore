defmodule Scheduler.Clients.RepoProxyClient do
  @moduledoc """
  Calls RepoProxy API
  """

  alias LogTee, as: LT
  alias Util.{Metrics, Proto, ToTuple}

  alias InternalApi.RepoProxy.{
    RepoProxyService,
    CreateRequest
  }

  defp url(), do: Application.get_env(:scheduler, :repo_proxy_api_grpc_endpoint)
  @opts [{:timeout, 15_500_000}]

  @doc """
  Entrypoint for create hook call from scheduler application.
  """
  def create(params) do
    result =
      Wormhole.capture(__MODULE__, :create_hook, [params],
        stacktrace: true,
        timeout: 16_000,
        ok_tuple: true
      )

    case result do
      {:ok, result} ->
        result |> Map.get(:workflow_id) |> ToTuple.ok()

      {:error, reason} ->
        reason
        |> LT.error("RepoProxy service responded to 'create' with:")
        |> ToTuple.error()
    end
  end

  def create_hook(params) do
    Metrics.benchmark("PeriodicSch.RepoProxyClient.create", fn ->
      request = Proto.deep_new!(CreateRequest, params)
      {:ok, channel} = GRPC.Stub.connect(url())

      RepoProxyService.Stub.create(channel, request, @opts)
    end)
  end
end
