defmodule PipelinesAPI.PipelinesClient.RequestFormatter do
  @moduledoc """
  Module serves to format data received from API client via HTTP into protobuf
  messages suitable for gRPC communication with Pipelines service.
  """

  alias PipelinesAPI.Util.ToTuple

  alias InternalApi.Plumber.{
    DescribeRequest,
    TerminateRequest,
    ListRequest,
    GetProjectIdRequest,
    DescribeTopologyRequest,
    ValidateYamlRequest,
    PartialRebuildRequest
  }

  alias LogTee, as: LT

  # Describe

  def form_describe_request(pipeline_id, params) when is_binary(pipeline_id) do
    %{ppl_id: pipeline_id, detailed: detailed?(params)}
    |> DescribeRequest.new()
    |> ToTuple.ok()
  end

  def form_describe_request(_error, _detailed),
    do: "Parameter pipeline_id must be a string." |> ToTuple.user_error()

  defp detailed?(map), do: map |> Map.get("detailed", "false") |> to_bool()

  defp to_bool(value) when value in ["true", "false"], do: String.to_existing_atom(value)
  defp to_bool(_value), do: false

  # Terminate

  def form_terminate_request(pipeline_id) when is_binary(pipeline_id) do
    %{ppl_id: pipeline_id} |> TerminateRequest.new() |> ToTuple.ok()
  end

  def form_terminate_request(_error),
    do: "Parameter pipeline_id must be a string." |> ToTuple.user_error()

  # List

  def form_list_request(params) when is_map(params) do
    with {:ok, page} <- non_zero_value_or_default(params, "page", 1),
         {:ok, page_size} <- non_zero_value_or_default(params, "page_size", 30),
         params <- Map.put(params, "page", page),
         params <- Map.put(params, "page_size", page_size),
         params <- cast_if_exists(params, "created_after", &unix_to_datetime/1),
         params <- cast_if_exists(params, "created_before", &unix_to_datetime/1),
         params <- cast_if_exists(params, "done_after", &unix_to_datetime/1),
         params <- cast_if_exists(params, "done_before", &unix_to_datetime/1) do
      Util.Proto.deep_new(
        ListRequest,
        params,
        string_keys_to_atoms: true,
        transformations: %{Google.Protobuf.Timestamp => {__MODULE__, :date_time_to_timestamps}}
      )
    end
  end

  def form_list_request(_), do: ToTuple.internal_error("Internal error")

  defp unix_to_datetime(value) do
    {value, _} =
      value
      |> Integer.parse()

    DateTime.from_unix(value)
  end

  def date_time_to_timestamps(_field_name, nil), do: %{seconds: 0, nanos: 0}

  def date_time_to_timestamps(_field_name, date_time = %DateTime{}) do
    %{}
    |> Map.put(:seconds, DateTime.to_unix(date_time, :second))
    |> Map.put(:nanos, elem(date_time.microsecond, 0) * 1_000)
  end

  def date_time_to_timestamps(_field_name, value), do: value

  defp cast_if_exists(map, key, cast_fun) do
    case Map.get(map, key) do
      nil ->
        map

      value ->
        cast_fun.(value)
        |> case do
          {:ok, value} ->
            Map.put(map, key, value)

          err ->
            LT.warn(err, "Can't parse #{key} value #{inspect(value)}}")
            map
        end
    end
  end

  defp non_zero_value_or_default(map, key, default) do
    case Map.get(map, key) do
      value when is_binary(value) -> int_value_or_default(value, default)
      _ -> {:ok, default}
    end
  end

  defp int_value_or_default(value, default) do
    case Integer.parse(value) do
      {num, _} when is_integer(num) and num > 0 -> {:ok, num}
      _ -> {:ok, default}
    end
  end

  # Get Project Id

  def form_get_project_id_request(pipeline_id) when is_binary(pipeline_id) do
    %{ppl_id: pipeline_id} |> GetProjectIdRequest.new() |> ToTuple.ok()
  end

  def form_get_project_id_request(_error),
    do: "Parameter pipeline_id must be a string." |> ToTuple.user_error()

  # DescribeTopology

  def form_describe_topology_request(pipeline_id) when is_binary(pipeline_id) do
    %{ppl_id: pipeline_id} |> DescribeTopologyRequest.new() |> ToTuple.ok()
  end

  def form_describe_topology_request(_error),
    do: "Parameter pipeline_id must be a string." |> ToTuple.user_error()

  # PartialRebuild

  def form_partial_rebuild_request(pipeline_id, request_token, user_id)
      when is_binary(pipeline_id) do
    with {:ok, req_token} <- check_request_token(request_token),
         do:
           %{ppl_id: pipeline_id, request_token: req_token, user_id: user_id}
           |> PartialRebuildRequest.new()
           |> ToTuple.ok()
  end

  def form_partial_rebuild_request(_), do: ToTuple.internal_error("Internal error")

  defp check_request_token(req_token) do
    case req_token do
      req_token when is_binary(req_token) and req_token != "" -> req_token |> ToTuple.ok()
      _ -> "Missing required post parameter request_token." |> ToTuple.user_error()
    end
  end

  # Validate YAML

  def form_validate_request(params) when is_map(params) do
    with {:ok, yaml_defintion} <- get_required_post_param(params, "yaml_definition"),
         pipeline_id <- Map.get(params, "pipeline_id") || "",
         do: form_validate_request_(yaml_defintion, pipeline_id)
  end

  def form_validate_request(_), do: ToTuple.internal_error("Internal error")

  def form_validate_request_(yaml_definition, pipeline_id)
      when is_binary(pipeline_id) and pipeline_id != "" do
    %{yaml_definition: yaml_definition, ppl_id: pipeline_id}
    |> ValidateYamlRequest.new()
    |> ToTuple.ok()
  end

  def form_validate_request_(yaml_definition, _pipeline_id) do
    %{yaml_definition: yaml_definition}
    |> ValidateYamlRequest.new()
    |> ToTuple.ok()
  end

  defp get_required_post_param(map, field_name) do
    case Map.get(map, field_name) do
      value when is_binary(value) and value != "" -> value |> ToTuple.ok()
      _ -> "Missing required post parameter #{field_name}." |> ToTuple.user_error()
    end
  end
end
