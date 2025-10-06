defmodule PipelinesAPI.PeriodicSchedulerClient.ResponseFormatter do
  @moduledoc """
  Module is used for parsing response from PeriodicScheduler service and transforming it
  from protobuf messages into more suitable format for HTTP communication with
  API clients
  """

  alias Google.Protobuf.Timestamp
  alias PipelinesAPI.Util.ToTuple
  alias Util.Proto
  alias LogTee, as: LT

  # Apply

  def process_apply_response({:ok, apply_response}) do
    with {:ok, response} <- Proto.to_map(apply_response),
         :OK <- response.status.code do
      {:ok, response.id}
    else
      :INVALID_ARGUMENT ->
        apply_response.status |> Map.get(:message) |> ToTuple.user_error()

      :FAILED_PRECONDITION ->
        apply_response.status |> Map.get(:message) |> ToTuple.user_error()

      _ ->
        log_invalid_response(apply_response, "apply")
    end
  end

  def process_apply_response(error), do: error

  # GetProjectId

  def process_get_project_id_response({:ok, proto_response}) do
    with {:ok, response} <- Proto.to_map(proto_response),
         :OK <- response.status.code do
      {:ok, response.project_id}
    else
      :INVALID_ARGUMENT ->
        proto_response.status |> Map.get(:message) |> ToTuple.user_error()

      :NOT_FOUND ->
        proto_response.status |> Map.get(:message) |> ToTuple.user_error()

      _ ->
        log_invalid_response(proto_response, "get_project_id")
    end
  end

  def process_get_project_id_response(error), do: error

  # Describe

  def process_describe_response({:ok, proto_response}) do
    with tf_map <- %{Timestamp => {__MODULE__, :timestamp_to_datetime_string}},
         {:ok, response} <- Proto.to_map(proto_response, transformations: tf_map),
         :OK <- response.status.code do
      {:ok,
       %{
         schedule: rename_reference_to_branch(response.periodic),
         triggers: rename_reference_to_branch(response.triggers)
       }}
    else
      :INVALID_ARGUMENT ->
        proto_response.status |> Map.get(:message) |> ToTuple.user_error()

      :NOT_FOUND ->
        proto_response.status |> Map.get(:message) |> ToTuple.user_error()

      _ ->
        log_invalid_response(proto_response, "describe")
    end
  end

  def process_describe_response(error), do: error

  # Delete

  def process_delete_response({:ok, proto_response}) do
    with {:ok, response} <- Proto.to_map(proto_response),
         :OK <- response.status.code do
      {:ok, "Schedule successfully deleted."}
    else
      :INVALID_ARGUMENT ->
        proto_response.status |> Map.get(:message) |> ToTuple.user_error()

      :NOT_FOUND ->
        proto_response.status |> Map.get(:message) |> ToTuple.user_error()

      _ ->
        log_invalid_response(proto_response, "delete")
    end
  end

  def process_delete_response(error), do: error

  # List

  def process_list_response({:ok, proto_response}) do
    with tf_map <- %{Timestamp => {__MODULE__, :timestamp_to_datetime_string}},
         {:ok, response} <- Proto.to_map(proto_response, transformations: tf_map),
         :OK <- response.status.code do
      response
      |> Map.put(:entries, rename_reference_to_branch(response.periodics))
      |> Map.drop([:periodics, :status])
      |> to_page()
      |> ToTuple.ok()
    else
      :INVALID_ARGUMENT ->
        proto_response.status |> Map.get(:message) |> ToTuple.user_error()

      _ ->
        log_invalid_response(proto_response, "list")
    end
  end

  def process_list_response(error), do: error

  defp to_page(map), do: struct(Scrivener.Page, map)

  # Run now

  def process_run_now_response({:ok, proto_response}) do
    with tf_map <- %{Timestamp => {__MODULE__, :timestamp_to_datetime_string}},
         {:ok, response} <- Proto.to_map(proto_response, transformations: tf_map),
         :OK <- response.status.code do
      {:ok, %{workflow_id: response.trigger.scheduled_workflow_id}}
    else
      :NOT_FOUND ->
        proto_response.status |> Map.get(:message) |> ToTuple.user_error()

      :INVALID_ARGUMENT ->
        proto_response.status |> Map.get(:message) |> ToTuple.user_error()

      :FAILED_PRECONDITION ->
        proto_response.status |> Map.get(:message) |> ToTuple.user_error()

      :RESOURCE_EXHAUSTED ->
        proto_response.status |> Map.get(:message) |> ToTuple.user_error()

      _ ->
        log_invalid_response(proto_response, "run_now")
    end
  end

  def process_run_now_response(error), do: error

  # Utility

  def timestamp_to_datetime_string(_name, %{nanos: 0, seconds: 0}), do: ""

  def timestamp_to_datetime_string(_name, %{nanos: nanos, seconds: seconds}) do
    ts_in_microseconds = seconds * 1_000_000 + Integer.floor_div(nanos, 1_000)
    {:ok, ts_date_time} = DateTime.from_unix(ts_in_microseconds, :microsecond)
    DateTime.to_string(ts_date_time)
  end

  defp rename_reference_to_branch(periodics) when is_list(periodics) do
    Enum.map(periodics, &rename_reference_to_branch/1)
  end

  defp rename_reference_to_branch(periodic) do
    case reference_to_branch_field(periodic.reference) do
      nil -> periodic
      branch_name -> Map.put(periodic, :branch, branch_name)
    end
  end

  def reference_to_branch_field("refs/heads/" <> branch_name), do: branch_name
  def reference_to_branch_field(_), do: nil

  defp log_invalid_response(response, rpc_method) do
    response
    |> LT.error("PeriodicScheduler service responded to #{rpc_method} with :ok and invalid data:")

    ToTuple.internal_error("Internal error")
  end
end
