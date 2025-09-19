defmodule InternalClients.Schedulers.ResponseFormatter do
  @moduledoc """
  Module parses the response from Guard RBAC service and transforms it
  from protobuf messages into more suitable format for HTTP communication with
  API clients.
  """

  alias InternalApi.PeriodicScheduler, as: API
  alias InternalApi.Status
  alias InternalClients.Common.User

  def process_response({:ok, r = %API.ListResponse{status: %Status{code: :OK}}}) do
    {:ok,
     %{
       entries: Enum.into(r.periodics, [], &task_from_pb/1),
       page_number: r.page_number,
       page_size: r.page_size,
       total_pages: r.total_pages,
       total_entries: r.total_entries
     }}
  end

  def process_response({:ok, r = %API.ListKeysetResponse{status: %Status{code: :OK}}}) do
    {:ok,
     %{
       entries: Enum.into(r.periodics, [], &task_from_pb/1),
       next_page_token: r.next_page_token,
       prev_page_token: r.prev_page_token,
       with_direction: true,
       page_size: r.page_size
     }}
  end

  def process_response({:ok, r = %API.DescribeResponse{status: %Status{code: :OK}}}) do
    {:ok, task_from_pb(r.periodic)}
  end

  def process_response({:ok, r = %API.PersistResponse{status: %Status{code: :OK}}}) do
    {:ok, task_from_pb(r.periodic)}
  end

  def process_response({:ok, %API.DeleteResponse{status: %InternalApi.Status{code: :OK}}}) do
    {:ok, %{}}
  end

  def process_response({:ok, r = %API.RunNowResponse{status: %Status{code: :OK}}}) do
    {:ok, trigger_from_pb(List.first(r.triggers))}
  end

  def process_response({:ok, r = %{status: %InternalApi.Status{code: :NOT_FOUND}}}) do
    {:error, {:not_found, r.status.message}}
  end

  def process_response({:ok, r = %{status: %InternalApi.Status{code: :INVALID_ARGUMENT}}}) do
    {:error, {:user, r.status.message}}
  end

  def process_response({:ok, r = %{status: %InternalApi.Status{code: :FAILED_PRECONDITION}}}) do
    {:error, {:user, r.status.message}}
  end

  def process_response({:ok, _r = %{status: %InternalApi.Status{code: _other_code}}}) do
    {:error, {:internal, "Unexpected error occurred"}}
  end

  def process_response(error), do: error

  defp task_from_pb(periodic = %API.Periodic{}) do
    %{
      apiVersion: "v2",
      kind: "Task",
      metadata: task_metadata_from_pb(periodic),
      spec: task_spec_from_pb(periodic)
    }
  end

  defp task_metadata_from_pb(periodic = %API.Periodic{}) do
    %{
      id: periodic.id,
      scheduled: periodic.recurring,
      project_id: periodic.project_id,
      suspended: periodic.suspended,
      paused: periodic.paused,
      updated_by: user_from_id(periodic.requester_id),
      paused_by: user_from_id(periodic.pause_toggled_by),
      inserted_at: PublicAPI.Util.Timestamps.to_timestamp(periodic.inserted_at),
      updated_at: PublicAPI.Util.Timestamps.to_timestamp(periodic.updated_at),
      paused_at: PublicAPI.Util.Timestamps.to_timestamp(periodic.pause_toggled_at)
    }
  end

  defp task_spec_from_pb(periodic = %API.Periodic{}) do
    %{
      name: periodic.name,
      description: periodic.description,
      reference: reference_from_pb(periodic.reference),
      pipeline_file: periodic.pipeline_file,
      cron_schedule: periodic.at,
      parameters: Enum.into(periodic.parameters, [], &parameter_from_pb/1)
    }
  end

  defp trigger_from_pb(trigger = %API.Trigger{}) do
    %{
      apiVersion: "v2",
      kind: "TaskTrigger",
      metadata: %{
        workflow_id: trigger.scheduled_workflow_id,
        triggered_by: user_from_id(trigger.run_now_requester_id),
        triggered_at: PublicAPI.Util.Timestamps.to_timestamp(trigger.triggered_at),
        scheduled_at: PublicAPI.Util.Timestamps.to_timestamp(trigger.scheduled_at),
        status: trigger.scheduling_status |> String.upcase()
      },
      spec: %{
        reference: reference_from_pb(trigger.reference),
        pipeline_file: trigger.pipeline_file,
        parameters: Enum.into(trigger.parameter_values, [], &parameter_value_from_pb/1)
      }
    }
  end

  defp trigger_from_pb(nil), do: %{}

  defp parameter_from_pb(parameter = %API.Periodic.Parameter{}) do
    %{
      name: parameter.name,
      description: parameter.description,
      required: parameter.required,
      default_value: parameter.default_value,
      options: parameter.options
    }
  end

  defp parameter_value_from_pb(parameter = %API.ParameterValue{}) do
    %{
      name: parameter.name,
      value: parameter.value
    }
  end

  defp reference_from_pb(reference) when is_binary(reference) do
    cond do
      String.starts_with?(reference, "refs/heads/") ->
        name = String.replace_prefix(reference, "refs/heads/", "")
        %{"type" => "branch", "name" => name}

      String.starts_with?(reference, "refs/tags/") ->
        name = String.replace_prefix(reference, "refs/tags/", "")
        %{"type" => "tag", "name" => name}

      true ->
        %{"type" => "branch", "name" => reference}
    end
  end

  defp reference_from_pb(_), do: %{"type" => "branch", "name" => ""}

  defp user_from_id(nil), do: nil
  defp user_from_id(""), do: nil
  defp user_from_id(uuid), do: User.from_id(uuid)
end
