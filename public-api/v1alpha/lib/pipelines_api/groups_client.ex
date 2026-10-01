defmodule PipelinesAPI.GroupsClient do
  @moduledoc false
  alias PipelinesAPI.GroupsClient.{GrpcClient, RequestFormatter, ResponseFormatter}
  alias PipelinesAPI.Util.Metrics

  def list(args, conn) do
    Metrics.benchmark("PipelinesAPI.groups_client", ["list"], fn ->
      args
      |> RequestFormatter.form_list_request(conn)
      |> GrpcClient.list()
      |> ResponseFormatter.process_list_response()
    end)
  end

  def create(args, conn) do
    Metrics.benchmark("PipelinesAPI.groups_client", ["create"], fn ->
      args
      |> RequestFormatter.form_create_request(conn)
      |> GrpcClient.create()
      |> ResponseFormatter.process_create_response()
    end)
  end

  def modify(args, conn) do
    Metrics.benchmark("PipelinesAPI.groups_client", ["modify"], fn ->
      args
      |> RequestFormatter.form_modify_request(conn)
      |> GrpcClient.modify()
      |> ResponseFormatter.process_modify_response()
    end)
  end

  def destroy(args, conn) do
    Metrics.benchmark("PipelinesAPI.groups_client", ["destroy"], fn ->
      args
      |> RequestFormatter.form_destroy_request(conn)
      |> GrpcClient.destroy()
      |> ResponseFormatter.process_destroy_response()
    end)
  end
end
