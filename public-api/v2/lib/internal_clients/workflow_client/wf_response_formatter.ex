defmodule InternalClients.Workflow.WFResponseFormatter do
  @moduledoc """
  Module is used for parsing response from Workflow service and transforming it
  from protobuf messages into more suitable format for HTTP communication with
  API clients
  """

  alias LogTee, as: LT
  alias PublicAPI.Util.ToTuple

  # List
  def process_list_response(resp = {:ok, list_response}, request) do
    with true <- is_map(list_response),
         {:ok, response_status} <- Map.fetch(list_response, :status),
         {:code, :OK} <- {:code, Map.get(response_status, :code)},
         {:ok, response} <- list_response(resp),
         response <- Map.put(response, :page_size, request.page_size) do
      {:ok, response}
    else
      _ ->
        log_invalid_response(list_response, "wf_list")
    end
  end

  def process_list_response(error), do: error

  defp list_response({:ok, resp}) do
    entries =
      resp
      |> Map.get(:workflows)
      |> Enum.map(&workflow_mapper/1)

    {:ok,
     %{
       entries: entries,
       next_page_token: resp.next_page_token,
       prev_page_token: resp.previous_page_token,
       with_direction: true
     }}
  end

  # Reschedule

  def process_reschedule_response({:ok, reschedule_response}) do
    with true <- is_map(reschedule_response),
         {:ok, status} <- Map.fetch(reschedule_response, :status),
         {:code, :OK} <- {:code, Map.get(status, :code)},
         {:ok, wf_id} <- Map.fetch(reschedule_response, :wf_id),
         {:ok, ppl_id} <- Map.fetch(reschedule_response, :ppl_id) do
      {:ok, %{wf_id: wf_id, ppl_id: ppl_id}}
    else
      {:code, _} -> when_status_code_not_ok(reschedule_response)
      _ -> log_invalid_response(reschedule_response, "schedule")
    end
  end

  def process_reschedule_response(error), do: error

  defp when_status_code_not_ok(reschedule_response) do
    reschedule_response
    |> Map.get(:status)
    |> ToTuple.user_error()
  end

  defp log_invalid_response(response, rpc_method) do
    response
    |> LT.error("Workflow service responded to #{rpc_method} with :ok and invalid data:")

    ToTuple.internal_error("Internal error")
  end

  # Terminate

  def process_terminate_response({:ok, terminate_response}) do
    with true <- is_map(terminate_response),
         {:ok, response_status} <- Map.fetch(terminate_response, :status),
         {:code, :OK} <- {:code, Map.get(response_status, :code)},
         {:ok, message} <- Map.fetch(response_status, :message) do
      {:ok, %{message: message}}
    else
      :BAD_PARAM ->
        terminate_response.response_status |> Map.get(:message) |> ToTuple.user_error()

      _ ->
        log_invalid_response(terminate_response, "wf terminate")
    end
  end

  def process_terminate_response(error), do: error

  # Describe

  def process_describe_response({:ok, describe_response}) do
    with true <- is_map(describe_response),
         {:ok, response_status} <- Map.fetch(describe_response, :status),
         {:code, :OK} <- {:code, Map.get(response_status, :code)},
         {:ok, workflow_proto} <- Map.fetch(describe_response, :workflow),
         {:ok, workflow} <- workflow_from_proto(workflow_proto) do
      {:ok, workflow}
    else
      {:code, :FAILED_PRECONDITION} ->
        ToTuple.not_found_error("Workflow not found")

      _e ->
        log_invalid_response(describe_response, "wf_describe")
    end
  end

  def process_describe_response(error), do: error

  # Renderer

  defp workflow_from_proto(workflow_proto) do
    alias PublicAPI.Util.Timestamps

    %{
      wf_id: workflow_proto.wf_id,
      requester_id: workflow_proto.requester_id,
      project_id: workflow_proto.project_id,
      triggered_by: Atom.to_string(workflow_proto.triggered_by),
      initial_ppl_id: workflow_proto.initial_ppl_id,
      hook_id: workflow_proto.hook_id,
      created_at: Timestamps.to_timestamp(workflow_proto.created_at),
      commit_sha: workflow_proto.commit_sha,
      branch_id: workflow_proto.branch_id
    }
    |> PublicAPI.Util.ToTuple.ok()
  end

  defp workflow_mapper(wf) do
    {:ok, wf_proto} = workflow_from_proto(wf)
    wf_proto
  end
end
