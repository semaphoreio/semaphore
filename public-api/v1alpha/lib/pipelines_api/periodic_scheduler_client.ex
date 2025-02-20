defmodule PipelinesAPI.PeriodicSchedulerClient do
  @moduledoc """
    Module is used for communication with Pipelines service over gRPC.
  """

  alias PipelinesAPI.PeriodicSchedulerClient.GrpcClient
  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.PeriodicSchedulerClient.RequestFormatter
  alias PipelinesAPI.PeriodicSchedulerClient.ResponseFormatter

  def apply(args, conn) do
    Metrics.benchmark("PipelinesAPI.periodic_scheduler_client", ["apply"], fn ->
      args
      |> RequestFormatter.form_apply_request(conn)
      |> GrpcClient.apply()
      |> ResponseFormatter.process_apply_response()
    end)
  end

  def get_project_id(args, conn) do
    Metrics.benchmark("PipelinesAPI.periodic_scheduler_client", ["get_project_id"], fn ->
      args
      |> RequestFormatter.form_get_project_id_request(conn)
      |> GrpcClient.get_project_id()
      |> ResponseFormatter.process_get_project_id_response()
    end)
  end

  def describe(args, conn) do
    Metrics.benchmark("PipelinesAPI.periodic_scheduler_client", ["describe"], fn ->
      args
      |> RequestFormatter.form_describe_request(conn)
      |> GrpcClient.describe()
      |> ResponseFormatter.process_describe_response()
    end)
  end

  def delete(args, conn) do
    Metrics.benchmark("PipelinesAPI.periodic_scheduler_client", ["delete"], fn ->
      args
      |> RequestFormatter.form_delete_request(conn)
      |> GrpcClient.delete()
      |> ResponseFormatter.process_delete_response()
    end)
  end

  def list(args, conn) do
    Metrics.benchmark("PipelinesAPI.periodic_scheduler_client", ["list"], fn ->
      args
      |> RequestFormatter.form_list_request(conn)
      |> GrpcClient.list()
      |> ResponseFormatter.process_list_response()
    end)
  end

  def run_now(args, conn) do
    Metrics.benchmark("PipelinesAPI.periodic_scheduler_client", ["run_now"], fn ->
      args
      |> RequestFormatter.form_run_now_request(conn)
      |> GrpcClient.run_now()
      |> ResponseFormatter.process_run_now_response()
    end)
  end
end
