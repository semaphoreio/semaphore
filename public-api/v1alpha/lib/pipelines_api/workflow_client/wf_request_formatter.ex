defmodule PipelinesAPI.WorkflowClient.WFRequestFormatter do
  @moduledoc """
  Module serves to format data received from API client via HTTP into protobuf
  messages suitable for gRPC communication with Workflow service.
  """

  alias Util.Proto
  alias InternalApi.PlumberWF.ScheduleRequest
  alias PipelinesAPI.Util.ToTuple
  alias InternalApi.PlumberWF.TerminateRequest
  alias InternalApi.PlumberWF.RescheduleRequest
  alias InternalApi.PlumberWF.DescribeRequest

  def form_schedule_request(params) when is_map(params) do
    %{
      service: service(params["service"]),
      repo: %{
        owner: params["owner"],
        repo_name: params["repo_name"],
        branch_name: params["branch_name"],
        commit_sha: params["commit_sha"]
      },
      auth: %{
        client_id: params["client_id"],
        client_secret: params["client_secret"],
        access_token: params["access_token"]
      },
      project_id: params["project_id"],
      branch_id: params["branch_id"],
      hook_id: params["hook_id"],
      request_token: params["ppl_request_token"],
      snapshot_id: Map.get(params, "snapshot_id", ""),
      definition_file: Map.get(params, "definition_file", ""),
      requester_id: Map.get(params, "requester_id", ""),
      organization_id: Map.get(params, "organization_id", "")
    }
    |> Proto.deep_new(ScheduleRequest)
  end

  def form_schedule_request(_), do: ToTuple.internal_error("Internal error")

  defp service(service_val) when is_integer(service_val), do: service_val

  defp service(service_val) when is_binary(service_val) do
    service_val
    |> String.upcase()
    |> String.to_atom()
    |> InternalApi.PlumberWF.ScheduleRequest.ServiceType.value()
  end

  defp service(_service_val), do: 0

  # Terminate

  def form_terminate_request(wf_id, requester_id) when is_binary(wf_id) do
    %{wf_id: wf_id, requester_id: requester_id} |> TerminateRequest.new() |> ToTuple.ok()
  end

  def form_terminate_request(_error),
    do: "Parameter wf_id must be a string." |> ToTuple.user_error()

  # Reschedule

  def form_reschedule_request(wf_id, requester_id, request_token) when is_binary(wf_id) do
    with {:ok, req_token} <- check_request_token(request_token),
         do:
           %{wf_id: wf_id, requester_id: requester_id, request_token: req_token}
           |> RescheduleRequest.new()
           |> ToTuple.ok()
  end

  def form_partial_rebuild_request(_), do: ToTuple.internal_error("Internal error")

  defp check_request_token(req_token) do
    case req_token do
      req_token when is_binary(req_token) and req_token != "" -> req_token |> ToTuple.ok()
      _ -> "Missing required post parameter request_token." |> ToTuple.user_error()
    end
  end

  # Describe

  def form_describe_request(wf_id) when is_binary(wf_id) do
    %{wf_id: wf_id}
    |> DescribeRequest.new()
    |> ToTuple.ok()
  end
end
