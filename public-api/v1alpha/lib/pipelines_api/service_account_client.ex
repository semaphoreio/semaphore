defmodule PipelinesAPI.ServiceAccountClient do
  @moduledoc false
  alias PipelinesAPI.ServiceAccountClient.{GrpcClient, RequestFormatter, ResponseFormatter}
  alias PipelinesAPI.Util.Metrics

  def create(args, conn) do
    Metrics.benchmark("PipelinesAPI.service_account_client", ["create"], fn ->
      args
      |> RequestFormatter.form_create_request(conn)
      |> GrpcClient.create()
      |> ResponseFormatter.process_create_response()
    end)
  end

  def list(args, conn) do
    Metrics.benchmark("PipelinesAPI.service_account_client", ["list"], fn ->
      args
      |> RequestFormatter.form_list_request(conn)
      |> GrpcClient.list()
      |> ResponseFormatter.process_list_response()
    end)
  end

  def describe(args, conn) do
    Metrics.benchmark("PipelinesAPI.service_account_client", ["describe"], fn ->
      args
      |> RequestFormatter.form_describe_request(conn)
      |> GrpcClient.describe()
      |> ResponseFormatter.process_describe_response()
    end)
  end

  def update(args, conn) do
    Metrics.benchmark("PipelinesAPI.service_account_client", ["update"], fn ->
      args
      |> RequestFormatter.form_update_request(conn)
      |> GrpcClient.update()
      |> ResponseFormatter.process_update_response()
    end)
  end

  def destroy(args, conn) do
    Metrics.benchmark("PipelinesAPI.service_account_client", ["destroy"], fn ->
      args
      |> RequestFormatter.form_destroy_request(conn)
      |> GrpcClient.destroy()
      |> ResponseFormatter.process_destroy_response()
    end)
  end

  def deactivate(args, conn) do
    Metrics.benchmark("PipelinesAPI.service_account_client", ["deactivate"], fn ->
      args
      |> RequestFormatter.form_deactivate_request(conn)
      |> GrpcClient.deactivate()
      |> ResponseFormatter.process_deactivate_response()
    end)
  end

  def reactivate(args, conn) do
    Metrics.benchmark("PipelinesAPI.service_account_client", ["reactivate"], fn ->
      args
      |> RequestFormatter.form_reactivate_request(conn)
      |> GrpcClient.reactivate()
      |> ResponseFormatter.process_reactivate_response()
    end)
  end

  def regenerate_token(args, conn) do
    Metrics.benchmark("PipelinesAPI.service_account_client", ["regenerate_token"], fn ->
      args
      |> RequestFormatter.form_regenerate_token_request(conn)
      |> GrpcClient.regenerate_token()
      |> ResponseFormatter.process_regenerate_token_response()
    end)
  end
end
