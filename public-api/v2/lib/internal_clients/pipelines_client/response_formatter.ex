defmodule InternalClients.Pipelines.ResponseFormatter do
  @moduledoc """
  Module is used for parsing response from Ppelines service and transforming it
  from protobuf messages into more suitable format for HTTP communication with
  API clients
  """

  alias LogTee, as: LT
  alias PublicAPI.Util.ToTuple

  # Describe

  def process_describe_response({:ok, describe_response}) do
    with true <- is_map(describe_response),
         {:ok, response_status} <- Map.fetch(describe_response, :response_status),
         {:code, :OK} <- {:code, Map.get(response_status, :code)},
         {:ok, pipeline} <- Map.fetch(describe_response, :pipeline),
         {:ok, pipeline} <- ppl_from_proto(pipeline),
         {:ok, blocks} <- Map.fetch(describe_response, :blocks),
         {:ok, blocks} <- blocks_from_proto(blocks) do
      %{pipeline: pipeline, blocks: blocks} |> ToTuple.ok()
    else
      {:code, :BAD_PARAM} ->
        describe_response.response_status |> Map.get(:message) |> ToTuple.user_error()

      _ ->
        log_invalid_response(describe_response, "describe")
    end
  end

  def process_describe_response(error), do: error

  defp ppl_from_proto!(ppl) do
    {:ok, res} = ppl_from_proto(ppl)
    res
  end

  defp ppl_from_proto(ppl) do
    alias PublicAPI.Util.Transformers

    ppl
    |> Transformers.transform_fields(:timestamps, [
      :created_at,
      :pending_at,
      :queuing_at,
      :running_at,
      :stopping_at,
      :done_at
    ])
    |> Transformers.transform_fields(:enums, [:state, :result, :result_reason])
    |> remove_result_if_not_done()
    |> terminated_by()
    |> Map.drop([:__unknown_fields__, :__struct__])
    |> ToTuple.ok()
  end

  defp remove_result_if_not_done(pipeline) do
    state = pipeline |> Map.get(:state, "") |> to_str()

    if state == "DONE" do
      pipeline
    else
      Map.drop(pipeline, [:result, :result_reason])
    end
  end

  defp terminated_by(ppl = %{terminated_by: ""}), do: %{ppl | terminated_by: nil}

  defp terminated_by(ppl = %{terminated_by: user_id}) do
    terminated_by = InternalClients.Common.User.from_id(user_id)
    %{ppl | terminated_by: terminated_by}
  end

  defp to_str(val) when is_atom(val), do: Atom.to_string(val)
  defp to_str(val) when is_binary(val), do: val

  defp blocks_from_proto(blocks) do
    alias PublicAPI.Util.Transformers

    Enum.map(blocks, fn block ->
      block
      |> Transformers.transform_fields(:enums, [:state, :result, :result_reason])
      |> remove_result_if_not_done()
      |> Map.drop([:__unknown_fields__, :__struct__])
    end)
    |> ToTuple.ok()
  end

  # Terminate

  def process_terminate_response({:ok, terminate_response}) do
    with true <- is_map(terminate_response),
         {:ok, response_status} <- Map.fetch(terminate_response, :response_status),
         {:code, :OK} <- {:code, Map.get(response_status, :code)},
         {:ok, message} <- Map.fetch(response_status, :message) do
      {:ok, %{message: message}}
    else
      {:code, :BAD_PARAM} ->
        terminate_response.response_status |> Map.get(:message) |> ToTuple.user_error()

      _ ->
        log_invalid_response(terminate_response, "terminate")
    end
  end

  def process_terminate_response(error), do: error

  # List

  def process_list_response({:ok, list_response}, request) do
    with true <- is_map(list_response),
         pipelines <- get_pipelines(list_response),
         {:ok, response} <- form_list_page(pipelines, list_response),
         response <- Map.put(response, :page_size, request.page_size) do
      {:ok, response}
    else
      :BAD_PARAM ->
        list_response.response_status |> Map.get(:message) |> ToTuple.user_error()

      _ ->
        log_invalid_response(list_response, "list")
    end
  end

  def process_list_response(error, _), do: error

  defp get_pipelines(list_response) do
    list_response.pipelines
    |> Enum.map(&ppl_from_proto!/1)
  end

  defp form_list_page(pipelines, list_response) when is_list(pipelines) do
    pipelines
    |> add_additional_fields(list_response)
    |> ToTuple.ok()
  end

  defp add_additional_fields(pipelines, list_response) do
    [:next_page_token, :previous_page_token]
    |> Enum.reduce(%{}, fn field, acc ->
      value = list_response |> Map.get(field)
      acc |> Map.put(field, value)
    end)
    |> Map.put(:with_direction, true)
    |> Map.put(:entries, pipelines)
  end

  # Describe Topology

  def process_describe_topology_response({:ok, describe_topology_response}) do
    with {:ok, status} <- Map.fetch(describe_topology_response, :status),
         {:code, :OK} <- {:code, Map.get(status, :code)},
         {:ok, blocks} <- Map.fetch(describe_topology_response, :blocks),
         {:ok, after_pipeline} <- Map.fetch(describe_topology_response, :after_pipeline) do
      blocks = Enum.map(blocks, &Map.drop(&1, [:__unknown_fields__, :__struct__]))
      after_pipeline = Map.drop(after_pipeline, [:__unknown_fields__, :__struct__])

      OpenApiSpex.Cast.cast(PublicAPI.Schemas.Pipelines.DescribeTopologyResponse.schema(), %{
        blocks: blocks,
        after_pipeline: after_pipeline
      })
    else
      {:code, :BAD_PARAM} ->
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
         {:code, :OK} <- {:code, Map.get(response_status, :code)},
         ppl_id when is_binary(ppl_id) <- Map.get(partial_rebuild_response, :ppl_id) do
      {:ok, %{message: response_status.message, pipeline_id: ppl_id}}
    else
      {:code, :BAD_PARAM} ->
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
    with {:ok, response_status} <- Map.fetch(validate_response, :response_status),
         {:code, :OK} <- {:code, Map.get(response_status, :code)},
         ppl_id when is_binary(ppl_id) <- Map.get(validate_response, :ppl_id, "") do
      {:ok, %{message: response_status.message}}
    else
      {:code, :BAD_PARAM} ->
        validate_response.response_status |> Map.get(:message) |> ToTuple.user_error()

      _ ->
        log_invalid_response(validate_response, "validate_yaml")
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

  defp log_invalid_response(response, rpc_method) do
    response
    |> LT.error("Pipelines service responded to #{rpc_method} with :ok and invalid data:")

    ToTuple.internal_error("Internal error")
  end
end
