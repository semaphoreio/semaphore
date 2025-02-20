defmodule InternalClients.Pipelines.RequestFormatter do
  @moduledoc """
  Module serves to format data received from API client via HTTP into protobuf
  messages suitable for gRPC communication with Pipelines service.
  """

  alias InternalApi.Plumber.ListKeysetRequest
  alias PublicAPI.Util.ToTuple

  alias InternalApi.Plumber.{
    DescribeRequest,
    TerminateRequest,
    DescribeTopologyRequest,
    ValidateYamlRequest,
    PartialRebuildRequest
  }

  import InternalClients.Common

  # Describe

  def form_describe_request(params) do
    %DescribeRequest{
      ppl_id: from_params!(params, :pipeline_id),
      detailed: from_params(params, :detailed, false)
    }
    |> ToTuple.ok()
  end

  # Terminate

  def form_terminate_request(pipeline_id) when is_binary(pipeline_id) do
    %TerminateRequest{ppl_id: pipeline_id} |> ToTuple.ok()
  end

  def form_terminate_request(_error),
    do: "Parameter pipeline_id must be a string." |> ToTuple.user_error()

  # List

  def form_list_request(params) when is_map(params) do
    alias PublicAPI.Util.Transformers

    with params <-
           Transformers.transform_fields(params, :from_timestamps, [
             :created_after,
             :created_before,
             :done_after,
             :done_before
           ]),
         params <- Transformers.transform_fields(params, :from_enums, [:direction]) do
      {:ok, struct(ListKeysetRequest, Keyword.new(params))}
    end
  end

  def form_list_request(_), do: ToTuple.internal_error("Internal error")

  # DescribeTopology

  def form_describe_topology_request(pipeline_id) when is_binary(pipeline_id) do
    %DescribeTopologyRequest{ppl_id: pipeline_id} |> ToTuple.ok()
  end

  def form_describe_topology_request(_error),
    do: "Parameter pipeline_id must be a string." |> ToTuple.user_error()

  # PartialRebuild

  def form_partial_rebuild_request(pipeline_id, request_token, user_id)
      when is_binary(pipeline_id) do
    with {:ok, req_token} <- check_request_token(request_token),
         do:
           %PartialRebuildRequest{ppl_id: pipeline_id, request_token: req_token, user_id: user_id}
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

  def form_validate_request(yaml_definition) do
    %ValidateYamlRequest{yaml_definition: yaml_definition}
    |> ToTuple.ok()
  end
end
