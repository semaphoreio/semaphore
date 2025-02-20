defmodule PipelinesAPI.DeploymentsClient do
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
  alias PipelinesAPI.DeploymentTargetsClient.{RequestFormatter, GrpcClient, ResponseFormatter}
  alias PipelinesAPI.Util.Metrics

  def list(list_params) do
    Metrics.benchmark("PipelinesAPI.deployments_client", ["list"], fn ->
      list_params
      |> RequestFormatter.form_list_request()
      |> GrpcClient.list()
      |> ResponseFormatter.process_list_response()
    end)
  end

  def create(create_params, conn) do
    Metrics.benchmark("PipelinesAPI.deployments_client", ["create"], fn ->
      create_params
      |> RequestFormatter.form_create_request(conn)
      |> GrpcClient.create()
      |> ResponseFormatter.process_create_response()
    end)
  end

  def update(update_params, conn) do
    Metrics.benchmark("PipelinesAPI.deployments_client", ["update"], fn ->
      update_params
      |> RequestFormatter.form_update_request(conn)
      |> GrpcClient.update()
      |> ResponseFormatter.process_update_response()
    end)
  end

  def delete(delete_params, conn) do
    Metrics.benchmark("PipelinesAPI.deployments_client", ["delete"], fn ->
      delete_params
      |> RequestFormatter.form_delete_request(conn)
      |> GrpcClient.delete()
      |> ResponseFormatter.process_delete_response()
    end)
  end

  def describe(describe_params) do
    Metrics.benchmark("PipelinesAPI.deployments_client", ["describe"], fn ->
      describe_params
      |> RequestFormatter.form_describe_request()
      |> GrpcClient.describe()
      |> ResponseFormatter.process_describe_response()
    end)
  end

  def history(history_params) do
    Metrics.benchmark("PipelinesAPI.deployments_client", ["history"], fn ->
      history_params
      |> RequestFormatter.form_history_request()
      |> GrpcClient.history()
      |> ResponseFormatter.process_history_response()
    end)
  end

  def cordon(cordon_params) do
    Metrics.benchmark("PipelinesAPI.deployments_client", ["cordon"], fn ->
      cordon_params
      |> RequestFormatter.form_cordon_request()
      |> GrpcClient.cordon()
      |> ResponseFormatter.process_cordon_response()
    end)
  end
end
