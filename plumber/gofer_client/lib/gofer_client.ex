defmodule GoferClient do
  @moduledoc """
  Module serves as a client for Gofer service, it collects all necessary parameters
  transforms them in proto messages, sends them to Gofer service, and parses proto
  response into format suitable for further use.
  """

  alias GoferClient.{RequestFormatter, GrpcClient, ResponseParser}

  def create_switch(yml_def_map, ppl_id, prev_ppl_artefact_ids, ref_args) do
    if System.get_env("SKIP_PROMOTIONS") == "true" do
      {:ok, ""}
    else
      create_switch_(yml_def_map, ppl_id, prev_ppl_artefact_ids, ref_args)
    end
  end

  def create_switch_(yml_def_map, ppl_id, prev_ppl_artefact_ids, ref_args) do
    yml_def_map
    |> RequestFormatter.form_create_request(ppl_id, prev_ppl_artefact_ids, ref_args)
    |> GrpcClient.create_switch()
    |> ResponseParser.process_create_response()
  end

  def pipeline_done(switch_id, result, result_reason) do
    if System.get_env("SKIP_PROMOTIONS") == "true" do
      {:ok, ""}
    else
      pipeline_done_(switch_id, result, result_reason)
    end
  end

  def pipeline_done_(switch_id, result, result_reason) do
    switch_id
    |> RequestFormatter.form_pipeline_done_request(result, result_reason)
    |> GrpcClient.pipeline_done()
    |> ResponseParser.process_pipeline_done_response()
  end

  def verify_deployment_target_access(target_id, triggerer, git_ref_type, git_ref_label) do
    target_id
    |> RequestFormatter.form_verify_request(triggerer, git_ref_type, git_ref_label)
    |> GrpcClient.verify_deployment_target_access()
    |> ResponseParser.process_verify_response()
  end
end
