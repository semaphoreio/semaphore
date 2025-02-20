defmodule InternalClients.Schedulers do
  @moduledoc """
  Facade used to communicate with periodic-scheduler service over gRPC.
  """

  alias InternalApi.PeriodicScheduler, as: API
  @metrics_name "InternalClients.Schedulers"

  defdelegate form_request(args), to: InternalClients.Schedulers.RequestFormatter
  defdelegate send_request(request), to: InternalClients.Schedulers.GrpcClient
  defdelegate process_response(response), to: InternalClients.Schedulers.ResponseFormatter

  def list(params), do: execute(API.ListRequest, params)
  def list_keyset(params), do: execute(API.ListKeysetRequest, params)
  def describe(params), do: execute(API.DescribeRequest, params)
  def persist(params), do: execute(API.PersistRequest, params)
  def delete(params), do: execute(API.DeleteRequest, params)
  def run_now(params), do: execute(API.RunNowRequest, params)

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
