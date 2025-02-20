defmodule InternalClients.Schedulers.GrpcClient do
  @moduledoc """
  Module is used for making gRPC calls to Guard RBAC service.
  """

  alias InternalApi.PeriodicScheduler, as: API
  alias PublicAPI.Util.{Log, Metrics}
  alias API.PeriodicService.Stub
  require Logger

  @metrics_name "InternalClients.Schedulers"

  def send_request({:ok, request}) do
    maybe_result =
      Wormhole.capture(__MODULE__, :do_send_request, [request],
        stacktrace: true,
        skip_log: true
      )

    case maybe_result do
      {:ok, result} -> result
      {:error, reason} -> Log.internal_error(reason, "list_project_members")
    end
  end

  def send_request(error = {:error, _reason}), do: error

  def do_send_request(request) do
    case GRPC.Stub.connect(endpoint_url()) do
      {:ok, channel} -> grpc_send(channel, request)
      {:error, _reason} = error -> error
    end
  end

  defp grpc_send(channel, request = %{__struct__: request_module}) do
    Metrics.benchmark(@metrics_name, [req_to_metric(request_module)], fn ->
      grpc_send(channel, req_to_func(request), request)
    end)
  end

  defp grpc_send(channel, func, request),
    do: func.(channel, request, grpc_opts()),
    after: GRPC.Stub.disconnect(channel)

  defp endpoint_url, do: System.get_env("PERIODIC_SCHEDULER_URL")
  defp grpc_opts, do: [{:timeout, Application.get_env(:public_api, :grpc_timeout)}]

  defp req_to_func(%API.ListRequest{}), do: &Stub.list/3
  defp req_to_func(%API.ListKeysetRequest{}), do: &Stub.list_keyset/3
  defp req_to_func(%API.DescribeRequest{}), do: &Stub.describe/3
  defp req_to_func(%API.PersistRequest{}), do: &Stub.persist/3
  defp req_to_func(%API.DeleteRequest{}), do: &Stub.delete/3
  defp req_to_func(%API.RunNowRequest{}), do: &Stub.run_now/3

  defp req_to_metric(request_module) do
    request_module
    |> Module.split()
    |> List.last()
    |> String.trim_trailing("Request")
    |> Macro.underscore()
  end
end
