defmodule PipelinesAPI.GoferClient do
  @moduledoc """
  Module is used for communication with Gofer service over gRPC.

  Each method execution returns either:

   - {:ok, result} -  When execution was successful

   - {:error, {:user, message}} - For user generetad errors (should be returned
     with HTTP 4xx code) that are recognized either by RequestFormatter
     (e.g. insufficient number of params) or by Gofer service which then
     returned :BAD_PARAM as response status code

   - {:error, {:refused, %{code: "REFUSED", message: message}}} - For trigger
     requests rejected by Gofer due to business constraints. Should be returned
     as HTTP 409.

   - {:error, {:internal, message}} - For all other errors, both known
     (e.g. gRPC timeouts) and unknown. In this case response should be returned
     with HTTP 5xx code.
  """
  alias PipelinesAPI.GoferClient.{RequestFormatter, GrpcClient, ResponseFormatter}
  alias PipelinesAPI.Util.Metrics

  def trigger(trigger_params) do
    Metrics.benchmark("PipelinesAPI.gofer_client", ["trigger"], fn ->
      trigger_params
      |> RequestFormatter.form_trigger_request()
      |> GrpcClient.trigger()
      |> ResponseFormatter.process_trigger_response()
    end)
  end

  def list(list_params) do
    Metrics.benchmark("PipelinesAPI.gofer_client", ["list"], fn ->
      list_params
      |> RequestFormatter.form_list_request()
      |> GrpcClient.list()
      |> ResponseFormatter.process_list_response()
    end)
  end
end
