defmodule Gofer.Grpc.ResponseFormatter do
  @moduledoc """
  Module serves to format action results into proper protobuf Response messages.
  """

  alias InternalApi.Gofer.{
    ResponseStatus,
    CreateResponse,
    PipelineDoneResponse,
    DescribeResponse,
    ListTriggerEventsResponse,
    TriggerResponse,
    EnvVariable,
    AutoTriggerCond,
    DescribeManyResponse
  }

  alias InternalApi.Gofer.TriggerEvent.ProcessingResult
  alias Google.Protobuf.Timestamp
  alias Util.Proto

  # Create

  def form_response({:ok, switch_id}, :create) do
    %{response_status: ok_status()}
    |> Map.merge(%{switch_id: switch_id})
    |> CreateResponse.new()
  end

  def form_response({:error, {:MALFORMED, message}}, :create) do
    %{response_status: status(:MALFORMED, message)}
    |> Map.merge(%{switch_id: ""})
    |> CreateResponse.new()
  end

  def form_response({:error, message}, :create) do
    %{response_status: error_status(message)}
    |> Map.merge(%{switch_id: ""})
    |> CreateResponse.new()
  end

  # Pipeline Done

  def form_response({:ok, {resp_code, message}}, :pipeline_done) do
    %{response_status: status(resp_code, message)}
    |> PipelineDoneResponse.new()
  end

  def form_response({:error, message}, :pipeline_done) do
    %{response_status: error_status(message)}
    |> PipelineDoneResponse.new()
  end

  # Trigger

  def form_response({:ok, {resp_code, message}}, :trigger) do
    %{response_status: status(resp_code, message)}
    |> TriggerResponse.new()
  end

  def form_response({:error, message}, :trigger) do
    %{response_status: error_status(message)}
    |> TriggerResponse.new()
  end

  # ListTriggerEvents

  def form_response({:ok, {:NOT_FOUND, message}}, :list_triggers) do
    %{response_status: status(:NOT_FOUND, message)}
    |> ListTriggerEventsResponse.new()
  end

  def form_response({:ok, page}, :list_triggers) do
    %{response_status: %{code: :OK}}
    |> Map.merge(page)
    |> form_list_response_proto()
  end

  def form_response({:error, message}, :list_triggers) do
    %{response_status: error_status(message)}
    |> ListTriggerEventsResponse.new()
  end

  # Describe

  def form_response({:ok, {:NOT_FOUND, message}}, :describe) do
    %{response_status: status(:NOT_FOUND, message)}
    |> DescribeResponse.new()
  end

  def form_response({:ok, description}, :describe) do
    %{response_status: %{code: :OK}}
    |> Map.merge(description)
    |> form_response_proto(DescribeResponse)
  end

  def form_response({:error, message}, :describe) do
    %{response_status: error_status(message)}
    |> DescribeResponse.new()
  end

  # DescribeMany

  def form_response({:ok, switches}, :describe_many) do
    %{response_status: %{code: :OK}}
    |> Map.merge(%{switches: switches})
    |> form_response_proto(DescribeManyResponse)
  end

  def form_response({:error, {:NOT_FOUND, message}}, :describe_many) do
    %{response_status: status(:NOT_FOUND, message)}
    |> DescribeManyResponse.new()
  end

  def form_response({:error, message}, :describe_many) do
    %{response_status: error_status(message)}
    |> DescribeManyResponse.new()
  end

  defp form_response_proto(description, module) do
    transformations = %{
      Timestamp => {Gofer.Grpc.ResponseFormatter, :date_time_to_timestamps},
      ProcessingResult => {Gofer.Grpc.ResponseFormatter, :string_to_enum_atom},
      EnvVariable => {Gofer.Grpc.ResponseFormatter, :keys_to_atom},
      AutoTriggerCond => {Gofer.Grpc.ResponseFormatter, :keys_to_atom}
    }

    Proto.deep_new!(module, description, transformations: transformations)
  end

  def date_time_to_timestamps(_field_name, nil), do: %{seconds: 0, nanos: 0}

  def date_time_to_timestamps(_field_name, date_time) do
    %{}
    |> Map.put(:seconds, DateTime.to_unix(date_time, :second))
    |> Map.put(:nanos, elem(date_time.microsecond, 0) * 1_000)
  end

  def string_to_enum_atom(_field_name, field_value)
      when is_binary(field_value) and field_value != "" do
    field_value |> String.upcase() |> String.to_atom()
  end

  def string_to_enum_atom(:processing_result, _field_value),
    do: :PASSED

  def keys_to_atom(_field_name, value) when is_map(value) do
    value |> Map.new(fn {k, v} -> {String.to_atom(k), v} end)
  end

  def keys_to_atom(_field_name, value), do: value

  # List

  defp form_list_response_proto(page) do
    transformations = %{
      Timestamp => {Gofer.Grpc.ResponseFormatter, :date_time_to_timestamps},
      ProcessingResult => {Gofer.Grpc.ResponseFormatter, :string_to_enum_atom},
      EnvVariable => {Gofer.Grpc.ResponseFormatter, :keys_to_atom},
      AutoTriggerCond => {Gofer.Grpc.ResponseFormatter, :keys_to_atom}
    }

    Proto.deep_new!(ListTriggerEventsResponse, page, transformations: transformations)
  end

  # Utility

  defp status(resp_code, message),
    do: ResponseStatus.new(code: resp_code, message: message)

  defp ok_status(message \\ ""), do: status(:OK, message)

  defp error_status({:error, message}), do: status(:BAD_PARAM, to_str(message))
  defp error_status(message), do: status(:BAD_PARAM, to_str(message))

  defp to_str(term) when is_binary(term), do: term
  defp to_str(term), do: inspect(term)
end
