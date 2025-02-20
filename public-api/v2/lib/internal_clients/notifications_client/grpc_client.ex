defmodule InternalClients.Notifications.GrpcClient do
  @moduledoc """
  Module is used for making gRPC calls to Notifications service.
  """

  alias InternalApi.Notifications, as: API
  alias PublicAPI.Util.{Log, Metrics}
  alias API.NotificationsApi.Stub
  require Logger

  @metrics_name "InternalClients.Notifications"

  def send_request({:ok, request}) do
    maybe_result =
      Wormhole.capture(__MODULE__, :do_send_request, [request],
        stacktrace: true,
        skip_log: true
      )

    case maybe_result do
      {:ok, result} -> result
      {:error, reason} -> Log.internal_error(reason, "Could not forward the request")
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

  defp endpoint_url, do: Application.get_env(:public_api, :notifications_grpc_endpoint)
  defp grpc_opts, do: [{:timeout, Application.get_env(:public_api, :grpc_timeout)}]

  defp req_to_func(%API.ListRequest{}), do: &Stub.list/3
  defp req_to_func(%API.DescribeRequest{}), do: &Stub.describe/3
  defp req_to_func(%API.DestroyRequest{}), do: &Stub.destroy/3
  defp req_to_func(%API.CreateRequest{}), do: &Stub.create/3
  defp req_to_func(%API.UpdateRequest{}), do: &Stub.update/3

  defp req_to_metric(request_module) do
    request_module
    |> Module.split()
    |> List.last()
    |> String.trim_trailing("Request")
    |> Macro.underscore()
  end
end
