defmodule InternalClients.Canvases.GrpcClient do
  @moduledoc """
  Module is used for making gRPC calls to canvas service.
  """

  alias InternalApi.Delivery, as: API
  alias PublicAPI.Util.{Log, Metrics}
  alias API.Delivery.Stub
  require Logger

  @metrics_name "InternalClients.Canvases"

  def send_request({:ok, request}) do
    maybe_result =
      Wormhole.capture(__MODULE__, :do_send_request, [request],
        stacktrace: true,
        skip_log: true
      )

    case maybe_result do
      {:ok, result} ->
        result

      {:error, reason} ->
        Log.internal_error(reason, "Could not forward the request", "Canvases")
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

  defp endpoint_url, do: Application.get_env(:public_api, :canvas_grpc_endpoint)
  defp grpc_opts, do: [{:timeout, Application.get_env(:public_api, :grpc_timeout)}]

  defp req_to_func(%API.CreateCanvasRequest{}), do: &Stub.create_canvas/3
  defp req_to_func(%API.DescribeCanvasRequest{}), do: &Stub.describe_canvas/3
  defp req_to_func(%API.CreateEventSourceRequest{}), do: &Stub.create_event_source/3
  defp req_to_func(%API.DescribeEventSourceRequest{}), do: &Stub.describe_event_source/3
  defp req_to_func(%API.ListEventSourcesRequest{}), do: &Stub.list_event_sources/3
  defp req_to_func(%API.CreateStageRequest{}), do: &Stub.create_stage/3
  defp req_to_func(%API.UpdateStageRequest{}), do: &Stub.update_stage/3
  defp req_to_func(%API.DescribeStageRequest{}), do: &Stub.describe_stage/3
  defp req_to_func(%API.ListStagesRequest{}), do: &Stub.list_stages/3
  defp req_to_func(%API.ListStageEventsRequest{}), do: &Stub.list_stage_events/3
  defp req_to_func(%API.ApproveStageEventRequest{}), do: &Stub.approve_stage_event/3

  defp req_to_metric(request_module) do
    request_module
    |> Module.split()
    |> List.last()
    |> String.trim_trailing("Request")
    |> Macro.underscore()
  end
end
