defmodule InternalClients.SelfHostedHub do
  @moduledoc """
    Module is used for communication with Self-Hosted Agents Hub service over gRPC.
  """

  alias InternalClients.SelfHostedHub.{GrpcClient, RequestFormatter, ResponseFormatter}
  alias PublicAPI.Util.Metrics

  def create(args) do
    Metrics.benchmark("InternalClients.self_hosted_hub_client", ["create"], fn ->
      args
      |> RequestFormatter.form_create_request()
      |> GrpcClient.create()
      |> ResponseFormatter.process_create_response()
    end)
  end

  def update(args) do
    Metrics.benchmark("InternalClients.self_hosted_hub_client", ["update"], fn ->
      args
      |> RequestFormatter.form_update_request()
      |> GrpcClient.update()
      |> ResponseFormatter.process_update_response()
    end)
  end

  def describe(args) do
    Metrics.benchmark("InternalClients.self_hosted_hub_client", ["describe"], fn ->
      args
      |> RequestFormatter.form_describe_request()
      |> GrpcClient.describe()
      |> ResponseFormatter.process_describe_response()
    end)
  end

  def describe_agent(args) do
    Metrics.benchmark("InternalClients.self_hosted_hub_client", ["describe_agent"], fn ->
      args
      |> RequestFormatter.form_describe_agent_request()
      |> GrpcClient.describe_agent()
      |> ResponseFormatter.process_describe_agent_response()
    end)
  end

  def list(args) do
    Metrics.benchmark("InternalClients.self_hosted_hub_client", ["list"], fn ->
      args
      |> RequestFormatter.form_list_request()
      |> GrpcClient.list()
      |> ResponseFormatter.process_list_response()
    end)
  end

  def list_agents(args) do
    Metrics.benchmark("InternalClients.self_hosted_hub_client", ["list_agents"], fn ->
      args
      |> RequestFormatter.form_list_agents_request()
      |> GrpcClient.list_agents()
      |> ResponseFormatter.process_list_agents_response()
    end)
  end

  def delete(args) do
    Metrics.benchmark("InternalClients.self_hosted_hub_client", ["delete"], fn ->
      args
      |> RequestFormatter.form_delete_request()
      |> GrpcClient.delete()
      |> ResponseFormatter.process_delete_response()
    end)
  end

  def disable_all(args) do
    Metrics.benchmark("InternalClients.self_hosted_hub_client", ["disable"], fn ->
      args
      |> RequestFormatter.form_disable_all_request()
      |> GrpcClient.disable_all()
      |> ResponseFormatter.process_disable_all_response()
    end)
  end
end
