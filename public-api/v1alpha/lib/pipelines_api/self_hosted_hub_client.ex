defmodule PipelinesAPI.SelfHostedHubClient do
  @moduledoc """
    Module is used for communication with Self-Hosted Agents Hub service over gRPC.
  """

  alias PipelinesAPI.SelfHostedHubClient.{GrpcClient, RequestFormatter, ResponseFormatter}
  alias PipelinesAPI.Util.Metrics

  def create(args, conn) do
    Metrics.benchmark("PipelinesAPI.self_hosted_hub_client", ["create"], fn ->
      args
      |> RequestFormatter.form_create_request(conn)
      |> GrpcClient.create()
      |> ResponseFormatter.process_create_response()
    end)
  end

  def update(args, conn) do
    Metrics.benchmark("PipelinesAPI.self_hosted_hub_client", ["update"], fn ->
      args
      |> RequestFormatter.form_update_request(conn)
      |> GrpcClient.update()
      |> ResponseFormatter.process_update_response()
    end)
  end

  def describe(args, conn) do
    Metrics.benchmark("PipelinesAPI.self_hosted_hub_client", ["describe"], fn ->
      args
      |> RequestFormatter.form_describe_request(conn)
      |> GrpcClient.describe()
      |> ResponseFormatter.process_describe_response()
    end)
  end

  def describe_agent(args, conn) do
    Metrics.benchmark("PipelinesAPI.self_hosted_hub_client", ["describe_agent"], fn ->
      args
      |> RequestFormatter.form_describe_agent_request(conn)
      |> GrpcClient.describe_agent()
      |> ResponseFormatter.process_describe_agent_response()
    end)
  end

  def list(args, conn) do
    Metrics.benchmark("PipelinesAPI.self_hosted_hub_client", ["list"], fn ->
      args
      |> RequestFormatter.form_list_request(conn)
      |> GrpcClient.list()
      |> ResponseFormatter.process_list_response()
    end)
  end

  def list_agents(args, conn) do
    Metrics.benchmark("PipelinesAPI.self_hosted_hub_client", ["list_agents"], fn ->
      args
      |> RequestFormatter.form_list_agents_request(conn)
      |> GrpcClient.list_agents()
      |> ResponseFormatter.process_list_agents_response()
    end)
  end

  def delete(args, conn) do
    Metrics.benchmark("PipelinesAPI.self_hosted_hub_client", ["delete"], fn ->
      args
      |> RequestFormatter.form_delete_request(conn)
      |> GrpcClient.delete()
    end)
  end

  def disable_all(args, conn) do
    Metrics.benchmark("PipelinesAPI.self_hosted_hub_client", ["disable"], fn ->
      args
      |> RequestFormatter.form_disable_all_request(conn)
      |> GrpcClient.disable_all()
    end)
  end
end
