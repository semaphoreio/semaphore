defmodule InternalClients.Projecthub do
  @moduledoc """
  Facade used to communicate with projecthub service over gRPC.
  """

  alias InternalApi.Projecthub, as: API
  @metrics_name "InternalClients.Projecthub"

  defdelegate form_request(args), to: InternalClients.Projecthub.RequestFormatter
  defdelegate send_request(request), to: InternalClients.Projecthub.GrpcClient
  defdelegate process_response(response), to: InternalClients.Projecthub.ResponseFormatter

  def list(params), do: execute(API.ListKeysetRequest, params)
  def describe(params), do: execute(API.DescribeRequest, params)
  def create(params), do: execute(API.CreateRequest, params)
  def update(params), do: execute(API.UpdateRequest, params)
  def delete(params), do: execute(API.DestroyRequest, params)

  def describe_many(params), do: execute(API.DescribeManyRequest, params)

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
