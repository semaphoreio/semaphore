defmodule PipelinesAPI.WorkflowClient.WFResponseFormatter do
  @moduledoc """
  Module is used for parsing response from Workflow service and transforming it
  from protobuf messages into more suitable format for HTTP communication with
  API clients
  """

  alias LogTee, as: LT
  alias Util.Proto
  alias PipelinesAPI.Util.ToTuple
  alias InternalApi.Plumber.ResponseStatus.ResponseCode
  alias Google.Protobuf.Timestamp
  alias InternalApi.PlumberWF.TriggeredBy

  # Schedule

  def process_schedule_response({:ok, schedule_response}) do
    with true <- is_map(schedule_response),
         response_map <- Proto.to_map!(schedule_response),
         {:ok, status} <- Map.fetch(response_map, :status),
         {:code, :OK} <- {:code, Map.get(status, :code)},
         {:ok, wf_id} <- Map.fetch(schedule_response, :wf_id),
         {:ok, ppl_id} <- Map.fetch(schedule_response, :ppl_id) do
      {:ok, %{workflow_id: wf_id, pipeline_id: ppl_id}}
    else
      {:code, _} -> when_status_code_not_ok(schedule_response)
      _ -> log_invalid_response(schedule_response, "schedule")
    end
  end

  def process_schedule_response(error), do: error

  defp when_status_code_not_ok(schedule_response) do
    schedule_response
    |> Proto.to_map!()
    |> Map.get(:status)
    |> Map.get(:message)
    |> ToTuple.user_error()
  end

  defp log_invalid_response(response, rpc_method) do
    response
    |> LT.error("Workflow service responded to #{rpc_method} with :ok and invalid data:")

    ToTuple.internal_error("Internal error")
  end

  # Reschedule

  def process_reschedule_response({:ok, reschedule_response}) do
    with true <- is_map(reschedule_response),
         response_map <- Proto.to_map!(reschedule_response),
         {:ok, status} <- Map.fetch(response_map, :status),
         {:code, :OK} <- {:code, Map.get(status, :code)},
         {:ok, wf_id} <- Map.fetch(reschedule_response, :wf_id),
         {:ok, ppl_id} <- Map.fetch(reschedule_response, :ppl_id) do
      {:ok, %{wf_id: wf_id, ppl_id: ppl_id}}
    else
      {:code, _} ->
        reschedule_response
        |> Proto.to_map!()
        |> Map.get(:status)
        |> ToTuple.user_error()

      _ ->
        log_invalid_response(reschedule_response, "reschedule")
    end
  end

  def process_reschedule_response(error), do: error

  # Terminate

  def process_terminate_response({:ok, terminate_response}) do
    with true <- is_map(terminate_response),
         {:ok, response_status} <- Map.fetch(terminate_response, :status),
         :OK <- response_code_value(response_status),
         {:ok, message} <- Map.fetch(response_status, :message) do
      {:ok, message}
    else
      :BAD_PARAM ->
        terminate_response.response_status |> Map.get(:message) |> ToTuple.user_error()

      _ ->
        log_invalid_response(terminate_response, "wf terminate")
    end
  end

  def process_terminate_response(error), do: error

  defp response_code_value(%{code: code}) do
    ResponseCode.key(code)
  rescue
    _ ->
      nil
  end

  defp response_code_value(_), do: nil

  # Describe

  def process_describe_response({:ok, describe_response}, full_fromat) do
    with true <- is_map(describe_response),
         {:ok, response_status} <- Map.fetch(describe_response, :status),
         :OK <- response_code_value(response_status),
         {:ok, workflow_proto} <- Map.fetch(describe_response, :workflow),
         {:ok, workflow} <- workflow_from_proto(workflow_proto, full_fromat) do
      {:ok, %{workflow: workflow}}
    else
      _ -> log_invalid_response(describe_response, "wf_describe")
    end
  end

  def process_describe_response(error), do: error

  defp workflow_from_proto(workflow_proto, true) do
    tf_map = %{
      Timestamp => {__MODULE__, :timestamp_to_datetime_string},
      TriggeredBy => {__MODULE__, :enum_to_string}
    }

    Proto.to_map(workflow_proto, transformations: tf_map)
  end

  defp workflow_from_proto(workflow_proto, _full_fromat) do
    Proto.to_map(workflow_proto)
  end

  # Utility

  def timestamp_to_datetime_string(_name, %{nanos: 0, seconds: 0}), do: ""

  def timestamp_to_datetime_string(_name, %{nanos: nanos, seconds: seconds}) do
    ts_in_microseconds = seconds * 1_000_000 + Integer.floor_div(nanos, 1_000)
    {:ok, ts_date_time} = DateTime.from_unix(ts_in_microseconds, :microsecond)
    DateTime.to_string(ts_date_time)
  end

  def enum_to_string(_name, value) when is_binary(value) do
    value |> Atom.to_string() |> String.downcase()
  end

  def enum_to_string(_name, value) when is_integer(value) do
    value |> TriggeredBy.key() |> Atom.to_string() |> String.downcase()
  end
end
