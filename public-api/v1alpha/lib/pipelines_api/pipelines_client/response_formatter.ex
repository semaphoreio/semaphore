defmodule PipelinesAPI.PipelinesClient.ResponseFormatter do
  @moduledoc """
  Module is used for parsing response from Ppelines service and transforming it
  from protobuf messages into more suitable format for HTTP communication with
  API clients
  """

  alias LogTee, as: LT
  alias PipelinesAPI.Util.ToTuple
  alias InternalApi.Plumber.ResponseStatus.ResponseCode
  alias InternalApi.Plumber.{Pipeline, Block}
  alias Util.Proto

  # Describe

  def process_describe_response({:ok, describe_response}) do
    with true <- is_map(describe_response),
         {:ok, response_status} <- Map.fetch(describe_response, :response_status),
         :OK <- response_code_value(response_status),
         {:ok, pipeline} <- Map.fetch(describe_response, :pipeline),
         {:ok, pipeline} <- ppl_from_proto(pipeline),
         {:ok, blocks} <- Map.fetch(describe_response, :blocks),
         {:ok, blocks} <- blocks_from_proto(blocks) do
      {:ok, %{pipeline: pipeline, blocks: blocks}}
    else
      :BAD_PARAM -> describe_response.response_status |> Map.get(:message) |> ToTuple.user_error()
      _ -> log_invalid_response(describe_response, "describe")
    end
  end

  def process_describe_response(error), do: error

  defp ppl_from_proto(ppl) do
    ppl
    |> from_proto(:state, :ppl)
    |> from_proto(:result, :ppl)
    |> from_proto(:result_reason, :ppl)
    |> transform_timestamps()
    |> remove_result_if_not_done()
    |> ToTuple.ok()
  end

  defp remove_result_if_not_done(pipeline) do
    state = pipeline |> Map.get(:state, "") |> to_str() |> String.downcase()

    if state == "done" do
      pipeline
    else
      Map.drop(pipeline, [:result, :result_reason])
    end
  end

  defp to_str(val) when is_atom(val), do: Atom.to_string(val)
  defp to_str(val) when is_binary(val), do: val

  defp transform_timestamps(ppl) do
    [:created_at, :pending_at, :queuing_at, :running_at, :stopping_at, :done_at]
    |> Enum.reduce(ppl, fn key, acc ->
      Map.update!(acc, key, fn timestamp -> to_date_time(timestamp) end)
    end)
  end

  defp to_date_time(timestamp) do
    ts_in_microseconds = timestamp.seconds * 1_000_000 + Integer.floor_div(timestamp.nanos, 1_000)
    {:ok, ts_date_time} = DateTime.from_unix(ts_in_microseconds, :microsecond)
    DateTime.to_string(ts_date_time)
  end

  defp blocks_from_proto(blocks) do
    Enum.map(blocks, fn block ->
      block
      |> from_proto(:state, :block)
      |> from_proto(:result, :block)
      |> from_proto(:result_reason, :block)
      |> remove_result_if_not_done()
    end)
    |> ToTuple.ok()
  end

  defp from_proto(map, key, entity) do
    map |> Map.update!(key, fn value -> int_to_enum(value, key, entity) end)
  end

  defp int_to_enum(value, :state, :ppl),
    do: value |> Pipeline.State.key() |> Atom.to_string() |> String.downcase()

  defp int_to_enum(value, :result, :ppl),
    do: value |> Pipeline.Result.key() |> Atom.to_string() |> String.downcase()

  defp int_to_enum(value, :result_reason, :ppl),
    do: value |> Pipeline.ResultReason.key() |> Atom.to_string() |> String.downcase()

  defp int_to_enum(value, :state, :block),
    do: value |> Block.State.key() |> Atom.to_string() |> String.downcase()

  defp int_to_enum(value, :result, :block),
    do: value |> Block.Result.key() |> Atom.to_string() |> String.downcase()

  defp int_to_enum(value, :result_reason, :block),
    do: value |> Block.ResultReason.key() |> Atom.to_string() |> String.downcase()

  # Terminate

  def process_terminate_response({:ok, terminate_response}) do
    with true <- is_map(terminate_response),
         {:ok, response_status} <- Map.fetch(terminate_response, :response_status),
         :OK <- response_code_value(response_status),
         {:ok, message} <- Map.fetch(response_status, :message) do
      {:ok, message}
    else
      :BAD_PARAM ->
        terminate_response.response_status |> Map.get(:message) |> ToTuple.user_error()

      _ ->
        log_invalid_response(terminate_response, "terminate")
    end
  end

  def process_terminate_response(error), do: error

  # List

  def process_list_response({:ok, list_response}) do
    with true <- is_map(list_response),
         {:ok, response_status} <- Map.fetch(list_response, :response_status),
         :OK <- response_code_value(response_status),
         pipelines <- get_pipelines(list_response),
         {:ok, response} <- form_list_page(pipelines, list_response) do
      {:ok, response}
    else
      :BAD_PARAM -> list_response.response_status |> Map.get(:message) |> ToTuple.user_error()
      _ -> log_invalid_response(list_response, "list")
    end
  end

  def process_list_response(error), do: error

  defp get_pipelines(list_response) do
    Proto.to_map!(list_response)[:pipelines]
    |> Enum.map(&remove_result_if_not_done(&1))
  end

  defp form_list_page(pipelines, list_response) when is_list(pipelines) do
    pipelines
    |> add_additional_fields(list_response)
    |> to_page()
    |> ToTuple.ok()
  end

  defp form_list_page(_, _), do: {:error, "Not a list"}

  defp add_additional_fields(pipelines, list_response) do
    [:page_number, :page_size, :total_entries, :total_pages]
    |> Enum.reduce(%{}, fn field, acc ->
      value = list_response |> Map.get(field)
      acc |> Map.put(field, value)
    end)
    |> Map.put(:entries, pipelines)
  end

  defp to_page(map), do: struct(Scrivener.Page, map)

  # Get Project Id

  def process_get_project_id_response({:ok, get_project_id_response}) do
    with true <- is_map(get_project_id_response),
         {:ok, response_status} <- Map.fetch(get_project_id_response, :response_status),
         :OK <- response_code_value(response_status),
         {:ok, project_id} <- Map.fetch(get_project_id_response, :project_id) do
      {:ok, project_id}
    else
      :BAD_PARAM ->
        get_project_id_response.response_status
        |> Map.get(:message)
        |> ToTuple.user_error()

      _ ->
        log_invalid_response(get_project_id_response, "get_project_id")
    end
  end

  def process_get_project_id_response(error), do: error

  # Describe Topology

  def process_describe_topology_response({:ok, describe_topology_response}) do
    with true <- is_map(describe_topology_response),
         {:ok, status} <- Map.fetch(describe_topology_response, :status),
         :OK <- response_code_value(status),
         {:ok, blocks} <- Map.fetch(describe_topology_response, :blocks) do
      {:ok, blocks}
    else
      :BAD_PARAM ->
        describe_topology_response.response_status
        |> Map.get(:message)
        |> ToTuple.user_error()

      _ ->
        log_invalid_response(describe_topology_response, "describe_topology_response")
    end
  end

  def process_describe_topology_response(error), do: error

  # Partial Rebuild

  def process_partial_rebuild_response({:ok, partial_rebuild_response}) do
    with true <- is_map(partial_rebuild_response),
         {:ok, response_status} <- Map.fetch(partial_rebuild_response, :response_status),
         :OK <- response_code_value(response_status),
         ppl_id when is_binary(ppl_id) <- Map.get(partial_rebuild_response, :ppl_id) do
      {:ok, %{message: response_status.message, pipeline_id: ppl_id}}
    else
      :BAD_PARAM ->
        partial_rebuild_response.response_status
        |> Map.get(:message)
        |> ToTuple.user_error()

      _ ->
        log_invalid_response(partial_rebuild_response, "partial_rebuild_response")
    end
  end

  def process_partial_rebuild_response(error), do: error

  # Validate YAML

  def process_validate_response({:ok, validate_response}) do
    with true <- is_map(validate_response),
         {:ok, response_status} <- Map.fetch(validate_response, :response_status),
         :OK <- response_code_value(response_status),
         ppl_id when is_binary(ppl_id) <- Map.get(validate_response, :ppl_id, "") do
      {:ok, %{message: response_status.message, pipeline_id: ppl_id}}
    else
      :BAD_PARAM -> validate_response.response_status |> Map.get(:message) |> ToTuple.user_error()
      _ -> log_invalid_response(validate_response, "validate_yaml")
    end
  end

  def process_validate_response(error), do: error

  # Version

  def process_version_response({:ok, version_response}) when is_map(version_response) do
    version_response |> Map.get(:version, nil) |> process_version_response_(version_response)
  end

  def process_version_response({:ok, version_response}),
    do: log_invalid_response(version_response, "version")

  def process_version_response(error), do: error

  defp process_version_response_(nil, version_response),
    do: log_invalid_response(version_response, "version")

  defp process_version_response_(version, _) when is_binary(version), do: {:ok, version}

  # Util

  defp response_code_value(%{code: code}) do
    ResponseCode.key(code)
  rescue
    _ ->
      nil
  end

  defp response_code_value(_), do: nil

  defp log_invalid_response(response, rpc_method) do
    response
    |> LT.error("Pipelines service responded to #{rpc_method} with :ok and invalid data:")

    ToTuple.internal_error("Internal error")
  end
end
