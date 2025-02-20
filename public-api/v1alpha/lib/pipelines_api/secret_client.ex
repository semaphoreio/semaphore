defmodule PipelinesAPI.SecretClient do
  @moduledoc """
  Module is used for communication with SecretHub service over gRPC.
  """
  alias PipelinesAPI.SecretClient.{RequestFormatter, GrpcClient, ResponseFormatter}
  alias PipelinesAPI.Util.Metrics

  def key() do
    Metrics.benchmark("PipelinesAPI.secret_client", ["key"], fn ->
      RequestFormatter.form_key_request()
      |> GrpcClient.key()
      |> ResponseFormatter.process_key_response()
    end)
  end

  def describe(params, conn) do
    Metrics.benchmark("PipelinesAPI.secret_client", ["describe"], fn ->
      params
      |> RequestFormatter.form_describe_request(conn)
      |> GrpcClient.describe()
      |> ResponseFormatter.process_describe_response()
    end)
  end
end
