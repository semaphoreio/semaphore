defmodule InternalClients.DeploymentTargets do
  @moduledoc """
  Module is used for communication with Gofer service over gRPC.

  Each method execution returns either:

   - {:ok, result} -  When execution was successful

   - {:error, {:user, message}} - For user generetad errors (should be returned
     with HTTP 4xx code) that are recognized either by RequestFormatter
     (e.g. insufficient number of params) or by Gofer service which then
     returned :BAD_PARAM as response status code

   - {:error, {:internal, message}} - For all other errors, both known
     (e.g. gRPC timeouts) and unknown. In this case response should be returned
     with HTTP 5xx code.
  """
  alias InternalApi.Gofer.DeploymentTargets, as: API
  @metrics_name "InternalClients.GoferDT"

  defdelegate form_request(args), to: InternalClients.DeploymentTargetsClient.RequestFormatter
  defdelegate send_request(request), to: InternalClients.DeploymentTargetsClient.GrpcClient

  defdelegate process_response(response),
    to: InternalClients.DeploymentTargetsClient.ResponseFormatter

  def list(params), do: execute(API.ListRequest, params)
  def describe(params), do: execute(API.DescribeRequest, params)
  def delete(params), do: execute(API.DeleteRequest, params)
  def create(params), do: execute(API.CreateRequest, params)
  def update(params), do: execute(API.UpdateRequest, params)
  def history(params), do: execute(API.HistoryRequest, params)
  def cordon(params), do: execute(API.CordonRequest, params)

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
