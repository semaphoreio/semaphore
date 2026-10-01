defmodule PipelinesAPI.PreFlightChecksClient do
  @moduledoc """
  Module is used for communication with PreFlightChecksHub service over gRPC.

  Each method execution returns either:

   - {:ok, result} -  When execution was successful

   - {:error, {:user, message}} - For user generetad errors (should be returned
     with HTTP 4xx code) that are recognized either by RequestFormatter
     (e.g. insufficient number of params) or by PreFlightChecksHub service which
     then returned :INVALID_ARGUMENT as response status code

   - {:error, {:internal, message}} - For all other errors, both known
     (e.g. gRPC timeouts) and unknown. In this case response should be returned
     with HTTP 5xx code.
  """
  alias PipelinesAPI.PreFlightChecksClient.{RequestFormatter, GrpcClient, ResponseFormatter}
  alias PipelinesAPI.Util.Metrics

  def describe(describe_params, conn) do
    Metrics.benchmark("PipelinesAPI.pre_flight_checks_client", ["describe"], fn ->
      describe_params
      |> RequestFormatter.form_describe_request(conn)
      |> GrpcClient.describe()
      |> ResponseFormatter.process_describe_response()
    end)
  end

  def apply(apply_params, conn) do
    Metrics.benchmark("PipelinesAPI.pre_flight_checks_client", ["apply"], fn ->
      apply_params
      |> RequestFormatter.form_apply_request(conn)
      |> GrpcClient.apply()
      |> ResponseFormatter.process_apply_response()
    end)
  end

  def destroy(destroy_params, conn) do
    Metrics.benchmark("PipelinesAPI.pre_flight_checks_client", ["destroy"], fn ->
      destroy_params
      |> RequestFormatter.form_destroy_request(conn)
      |> GrpcClient.destroy()
      |> ResponseFormatter.process_destroy_response()
    end)
  end
end
