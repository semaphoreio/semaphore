defmodule InternalClients.Secrets do
  @moduledoc """
  Module is used for communication with Secrets seervice over gRPC.

  Each method execution returns after:
   - {:ok, result} -  When execution was successful

   - {:error, {:user, message}} - For user generetad errors (should be returned
     with HTTP 4xx code) that are recognized either by RequestFormatter
     (e.g. insufficient number of params) or by Pipelines service which then
     returned :BAD_PARAM as response status code

   - {:error, {:internal, message}} - For all other errors, both known
     (e.g. gRPC timeouts) and unknown. In this case response should be returned
     with HTTP 5xx code.
  """
  alias InternalApi.Secrethub, as: API
  @metrics_name "InternalClients.Secrethub"

  defdelegate form_request(args), to: InternalClients.Secrets.RequestFormatter
  defdelegate send_request(request), to: InternalClients.Secrets.GrpcClient
  defdelegate process_response(response), to: InternalClients.Secrets.ResponseFormatter

  def list(params), do: execute(API.ListKeysetRequest, params)
  def describe(params), do: execute(API.DescribeRequest, params)
  def delete(params), do: execute(API.DestroyRequest, params)
  def create(params), do: execute(API.CreateRequest, params)
  def update(params), do: execute(API.UpdateRequest, params)
  def key(), do: execute(API.GetKeyRequest, nil)

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
