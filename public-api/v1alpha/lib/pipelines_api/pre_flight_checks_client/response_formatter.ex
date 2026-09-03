defmodule PipelinesAPI.PreFlightChecksClient.ResponseFormatter do
  @moduledoc """
  Module parses the response from PreFlightChecksHub service and transforms it
  from protobuf messages into more suitable format for HTTP communication with
  API clients.

  A response carries specification for either the organization or the project,
  depending on the level of the request, and is flattened into a single object.
  """

  alias Google.Protobuf.Timestamp
  alias PipelinesAPI.Util.ToTuple
  alias Util.Proto
  alias LogTee, as: LT

  @response_fields ~w(commands secrets agent requester_id created_at updated_at)a

  # Describe

  def process_describe_response({:ok, describe_response}) do
    with {:ok, response} <- to_map(describe_response),
         :OK <- response.status.code do
      {:ok, flatten_pre_flight_checks(response.pre_flight_checks)}
    else
      :NOT_FOUND ->
        describe_response.status |> Map.get(:message) |> ToTuple.not_found_error()

      :INVALID_ARGUMENT ->
        describe_response.status |> Map.get(:message) |> ToTuple.unprocessable_error()

      _ ->
        log_invalid_response(describe_response, "describe")
    end
  end

  def process_describe_response(error), do: error

  # Apply

  def process_apply_response({:ok, apply_response}) do
    with {:ok, response} <- to_map(apply_response),
         :OK <- response.status.code do
      {:ok, flatten_pre_flight_checks(response.pre_flight_checks)}
    else
      :NOT_FOUND ->
        apply_response.status |> Map.get(:message) |> ToTuple.not_found_error()

      :INVALID_ARGUMENT ->
        apply_response.status |> Map.get(:message) |> ToTuple.unprocessable_error()

      _ ->
        log_invalid_response(apply_response, "apply")
    end
  end

  def process_apply_response(error), do: error

  # Destroy

  def process_destroy_response({:ok, destroy_response}) do
    with {:ok, response} <- to_map(destroy_response),
         :OK <- response.status.code do
      {:ok, "Pre-flight checks successfully deleted."}
    else
      :NOT_FOUND ->
        destroy_response.status |> Map.get(:message) |> ToTuple.not_found_error()

      :INVALID_ARGUMENT ->
        destroy_response.status |> Map.get(:message) |> ToTuple.unprocessable_error()

      _ ->
        log_invalid_response(destroy_response, "destroy")
    end
  end

  def process_destroy_response(error), do: error

  # Utility

  defp flatten_pre_flight_checks(%{project_pfc: pfc}) when is_map(pfc),
    do: Map.take(pfc, @response_fields)

  defp flatten_pre_flight_checks(%{organization_pfc: pfc}) when is_map(pfc),
    do: Map.take(pfc, @response_fields)

  defp flatten_pre_flight_checks(_pre_flight_checks), do: %{}

  defp to_map(response) do
    Proto.to_map(response,
      transformations: %{
        Timestamp => {__MODULE__, :timestamp_to_datetime_string}
      }
    )
  end

  def timestamp_to_datetime_string(_name, %{nanos: 0, seconds: 0}), do: ""

  def timestamp_to_datetime_string(_name, %{nanos: nanos, seconds: seconds}) do
    ts_in_microseconds = seconds * 1_000_000 + Integer.floor_div(nanos, 1_000)
    {:ok, ts_date_time} = DateTime.from_unix(ts_in_microseconds, :microsecond)
    ts_date_time |> DateTime.to_iso8601()
  end

  defp log_invalid_response(response, rpc_method) do
    response
    |> LT.error("PreFlightChecks service responded to #{rpc_method} with :ok and invalid data:")

    ToTuple.internal_error("Internal error")
  end
end
