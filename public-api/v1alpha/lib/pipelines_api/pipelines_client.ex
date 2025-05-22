defmodule PipelinesAPI.PipelinesClient do
  @moduledoc """
  Module is used for communication with Pipelines service over gRPC.

  Each method execution returns either:

   - {:ok, result} -  When execution was successful

   - {:error, {:user, message}} - For user generetad errors (should be returned
     with HTTP 4xx code) that are recognized either by RequestFormatter
     (e.g. insufficient number of params) or by Pipelines service which then
     returned :BAD_PARAM as response status code

   - {:error, {:internal, message}} - For all other errors, both known
     (e.g. gRPC timeouts) and unknown. In this case response should be returned
     with HTTP 5xx code.
  """

  alias InternalApi.Plumber.VersionRequest
  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.PipelinesClient.{RequestFormatter, GrpcClient, ResponseFormatter}

  def describe(pipeline_id, params) do
    Metrics.benchmark("PipelinesAPI.ppl_client", ["describe"], fn ->
      pipeline_id
      |> RequestFormatter.form_describe_request(params)
      |> GrpcClient.describe()
      |> ResponseFormatter.process_describe_response()
    end)
  end

  def terminate(pipeline_id) do
    Metrics.benchmark("PipelinesAPI.ppl_client", ["terminate"], fn ->
      pipeline_id
      |> RequestFormatter.form_terminate_request()
      |> GrpcClient.terminate()
      |> ResponseFormatter.process_terminate_response()
    end)
  end

  def list(query_params) do
    Metrics.benchmark("PipelinesAPI.ppl_client", ["list"], fn ->
      query_params
      |> RequestFormatter.form_list_request()
      |> GrpcClient.list()
      |> ResponseFormatter.process_list_response()
    end)
  end

  def get_project_id(pipeline_id) do
    Metrics.benchmark("PipelinesAPI.ppl_client", ["get_project_id"], fn ->
      pipeline_id
      |> RequestFormatter.form_get_project_id_request()
      |> GrpcClient.get_project_id()
      |> ResponseFormatter.process_get_project_id_response()
    end)
  end

  def describe_topology(pipeline_id) do
    Metrics.benchmark("PipelinesAPI.ppl_client", ["describe_topology"], fn ->
      pipeline_id
      |> RequestFormatter.form_describe_topology_request()
      |> GrpcClient.describe_topology()
      |> ResponseFormatter.process_describe_topology_response()
    end)
  end

  def partial_rebuild(pipeline_id, request_token, user_id) do
    Metrics.benchmark("PipelinesAPI.ppl_client", ["partial_rebuild"], fn ->
      RequestFormatter.form_partial_rebuild_request(pipeline_id, request_token, user_id)
      |> GrpcClient.partial_rebuild()
      |> ResponseFormatter.process_partial_rebuild_response()
    end)
  end

  def validate_yaml(post_params) do
    Metrics.benchmark("PipelinesAPI.ppl_client", ["validate_yaml"], fn ->
      post_params
      |> RequestFormatter.form_validate_request()
      |> GrpcClient.validate_yaml()
      |> ResponseFormatter.process_validate_response()
    end)
  end

  def version() do
    VersionRequest.new()
    |> GrpcClient.version()
    |> ResponseFormatter.process_version_response()
  end
end
