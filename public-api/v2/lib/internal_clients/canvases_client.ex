defmodule InternalClients.Canvases do
  @moduledoc """
  Module is used for communication with canvas seervice over gRPC.

  Each method execution returns after:
   - {:ok, result} -  When execution was successful

   - {:error, {:user, message}} - For user generated errors (should be returned
     with HTTP 4xx code) that are recognized either by RequestFormatter
     (e.g. insufficient number of params) or by Pipelines service which then
     returned :BAD_PARAM as response status code

   - {:error, {:internal, message}} - For all other errors, both known
     (e.g. gRPC timeouts) and unknown. In this case response should be returned
     with HTTP 5xx code.
  """
  alias InternalApi.Delivery, as: API
  @metrics_name "InternalClients.Canvases"

  defdelegate form_request(args), to: InternalClients.Canvases.RequestFormatter
  defdelegate send_request(request), to: InternalClients.Canvases.GrpcClient
  defdelegate process_response(response), to: InternalClients.Canvases.ResponseFormatter

  def create_canvas(params), do: execute(API.CreateCanvasRequest, params)
  def describe_canvas(params), do: execute(API.DescribeCanvasRequest, params)
  def create_event_source(params), do: execute(API.CreateEventSourceRequest, params)
  def describe_event_source(params), do: execute(API.DescribeEventSourceRequest, params)
  def list_event_sources(params), do: execute(API.ListEventSourcesRequest, params)
  def create_stage(params), do: execute(API.CreateStageRequest, params)
  def update_stage(params), do: execute(API.UpdateStageRequest, params)
  def describe_stage(params), do: execute(API.DescribeStageRequest, params)
  def list_stages(params), do: execute(API.ListStagesRequest, params)
  def list_stage_events(params), do: execute(API.ListStageEventsRequest, params)
  def approve_stage_event(params), do: execute(API.ApproveStageEventRequest, params)

  defp execute(request_module, params) do
    PublicAPI.Util.Metrics.benchmark(
      @metrics_name,
      [req_to_metric(request_module)],
      fn ->
        {request_module, params}
        |> form_request()
        |> send_request()
        |> process_response()
      end
    )
  end

  defp req_to_metric(request_module) do
    request_module
    |> Module.split()
    |> List.last()
    |> String.trim_trailing("Request")
    |> Macro.underscore()
  end
end
