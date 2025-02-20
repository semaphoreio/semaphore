defmodule InternalClients.Workflow do
  @moduledoc """
    Module is used for communication with Pipelines service over gRPC.
  """

  alias InternalClients.Workflow.WFGrpcClient
  alias PublicAPI.Util.Metrics
  alias InternalClients.Workflow.WFRequestFormatter
  alias InternalClients.Workflow.WFResponseFormatter

  def list(args) do
    Metrics.benchmark("PublicAPI.WorkflowClient", ["wf_list"], fn ->
      args
      |> WFRequestFormatter.from_list_request()
      |> WFGrpcClient.list()
      |> WFResponseFormatter.process_list_response(args)
    end)
  end

  def terminate(wf_id, requester_id) do
    Metrics.benchmark("PublicAPI.WorkflowClient", ["terminate"], fn ->
      WFRequestFormatter.form_terminate_request(wf_id, requester_id)
      |> WFGrpcClient.terminate()
      |> WFResponseFormatter.process_terminate_response()
    end)
  end

  def reschedule(wf_id, requester_id, request_token) do
    Metrics.benchmark("PublicAPI.WorkflowClient", ["reschedule"], fn ->
      WFRequestFormatter.form_reschedule_request(wf_id, requester_id, request_token)
      |> WFGrpcClient.reschedule()
      |> WFResponseFormatter.process_reschedule_response()
    end)
  end

  def describe(wf_id) do
    Metrics.benchmark("PublicAPI.WorkflowClient", ["wf_describe"], fn ->
      wf_id
      |> WFRequestFormatter.form_describe_request()
      |> WFGrpcClient.describe()
      |> WFResponseFormatter.process_describe_response()
    end)
  end
end
