defmodule InternalClients.Workflow.WFRequestFormatter do
  @moduledoc """
  Module serves to format data received from API client via HTTP into protobuf
  messages suitable for gRPC communication with Workflow service.
  """

  alias InternalApi.PlumberWF.ListKeysetRequest
  alias PublicAPI.Util.ToTuple
  alias InternalApi.PlumberWF.TerminateRequest
  alias InternalApi.PlumberWF.RescheduleRequest
  alias InternalApi.PlumberWF.DescribeRequest
  import InternalClients.Common

  def from_list_request(params) when is_map(params) do
    %ListKeysetRequest{
      page_token: Map.get(params, :page_token, ""),
      page_size: Map.get(params, :page_size, 30),
      project_id: Map.get(params, :project_id),
      branch_name: Map.get(params, :branch_name),
      requester_id: Map.get(params, :requester_id),
      organization_id: from_params!(params, :organization_id),
      created_before:
        PublicAPI.Util.Timestamps.to_google_protobuf(Map.get(params, :created_before)),
      created_after:
        PublicAPI.Util.Timestamps.to_google_protobuf(Map.get(params, :created_after)),
      label: Map.get(params, :label),
      git_ref_types: Map.get(params, :git_ref_types, []) |> Enum.map(&git_ref_type/1)
    }
    |> ToTuple.ok()
  end

  def from_list_request(_), do: ToTuple.internal_error("Internal error")

  defp git_ref_type(git_ref) when is_integer(git_ref), do: git_ref

  defp git_ref_type(git_ref) when is_binary(git_ref) do
    git_ref
    |> String.to_atom()
  end

  defp git_ref_type(_service_val), do: 0

  # Terminate

  def form_terminate_request(wf_id, requester_id) when is_binary(wf_id) do
    %TerminateRequest{wf_id: wf_id, requester_id: requester_id} |> ToTuple.ok()
  end

  def form_terminate_request(_error),
    do: "Parameter wf_id must be a string." |> ToTuple.user_error()

  # Reschedule

  def form_reschedule_request(wf_id, requester_id, request_token) when is_binary(wf_id) do
    with {:ok, req_token} <- check_request_token(request_token),
         do:
           %RescheduleRequest{wf_id: wf_id, requester_id: requester_id, request_token: req_token}
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
    %DescribeRequest{wf_id: wf_id}
    |> ToTuple.ok()
  end
end
