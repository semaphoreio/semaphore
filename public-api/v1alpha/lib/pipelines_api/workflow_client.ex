defmodule PipelinesAPI.WorkflowClient do
  @moduledoc """
    Module is used for communication with Pipelines service over gRPC.
  """

  alias PipelinesAPI.WorkflowClient.WFGrpcClient
  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.WorkflowClient.WFRequestFormatter
  alias PipelinesAPI.WorkflowClient.WFResponseFormatter

  def schedule(args) do
    Metrics.benchmark("PipelinesAPI.router", ["schedule_snapshot"], fn ->
      args
      |> WFRequestFormatter.form_schedule_request()
      |> WFGrpcClient.schedule()
      |> WFResponseFormatter.process_schedule_response()
    end)
  end

  def terminate(wf_id, requester_id) do
    Metrics.benchmark("PipelinesAPI.router", ["terminate"], fn ->
      WFRequestFormatter.form_terminate_request(wf_id, requester_id)
      |> WFGrpcClient.terminate()
      |> WFResponseFormatter.process_terminate_response()
    end)
  end

  def reschedule(wf_id, requester_id, request_token) do
    Metrics.benchmark("PipelinesAPI.router", ["reschedule"], fn ->
      WFRequestFormatter.form_reschedule_request(wf_id, requester_id, request_token)
      |> WFGrpcClient.reschedule()
      |> WFResponseFormatter.process_reschedule_response()
    end)
  end

  def describe(wf_id, full_fromat \\ false) do
    Metrics.benchmark("PipelinesAPI.router", ["wf_describe"], fn ->
      wf_id
      |> WFRequestFormatter.form_describe_request()
      |> WFGrpcClient.describe()
      |> WFResponseFormatter.process_describe_response(full_fromat)
    end)
  end
end
