defmodule Gofer.PlumberClient do
  @moduledoc """
  This module represents gRPC client for Plumber service.
  """

  alias Gofer.PlumberClient.{RequestFormatter, GrpcClient, ResponseParser}

  # TO DO: add the workflow ID to create switch rpc

  def schedule_pipeline(schedule_params) do
    with {:ok, request} <- RequestFormatter.form_schedule_extension_request(schedule_params),
         {:ok, response} <- GrpcClient.schedule_extension(request),
         {:ok, scheduled_ppl_id} <- ResponseParser.parse_response(response) do
      {:ok, scheduled_ppl_id}
    else
      e = {:error, _} -> e
      error -> {:error, error}
    end
  end

  def describe(pipeline_id) do
    with {:ok, request} <- RequestFormatter.form_describe_request(pipeline_id),
         {:ok, response} <- GrpcClient.describe(request),
         {:ok, ppl_state, ppl_result, ppl_result_reason, ppl_done_at} <-
           ResponseParser.parse_response(response) do
      {:ok, ppl_state, ppl_result, ppl_result_reason, ppl_done_at}
    else
      e = {:error, _} -> e
      error -> {:error, error}
    end
  end
end
