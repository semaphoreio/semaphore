defmodule GoferClient.RequestFormatter.Test do
  use ExUnit.Case

  alias GoferClient.RequestFormatter
  alias InternalApi.Gofer.{Target, CreateRequest, PipelineDoneRequest, ParamEnvVar, AutoTriggerCond}

  # Create

  test "when promotions are not defined in yml form_create_request() returnes {:ok, :switch_not_defined}" do
    ppl_id = UUID.uuid4()
    assert {:ok, :switch_not_defined}
              == RequestFormatter.form_create_request(%{}, ppl_id, [ppl_id], "master")
  end

  test "valid definition is turned into proto message correctly" do
    stg_target = %{"name" => "stg", "pipeline_file" => "./stg.yaml",
                   "auto_promote_on" => [%{"result" => "passed", "branch" => ["mast.", "xyz"]}]}
    prod_target = %{"name" => "prod", "pipeline_file" => "./prod.yaml",
                    "parameters" => %{"env_vars" =>
                    [%{"name" => "TEST", "options" => ["1", "2"], "default_value" => "9"},
                     %{"name" => "TEST_2", "required" => false, "description" => "asfef"}]}}
    art_store_target = %{"name" => "artifacts_storage", "pipeline_file" => "./art_store.yaml",
                         "auto_promote" => %{"when" => "result = 'passed'"}}
    switch_def = %{"promotions" => [stg_target, prod_target, art_store_target]}
    ppl_id = UUID.uuid4()
    ref_args = %{branch_name: "master", label: "master", git_ref_type: "pr"}

    assert {:ok, request} = RequestFormatter.form_create_request(switch_def, ppl_id, [ppl_id], ref_args)
    assert %CreateRequest{pipeline_id: ^ppl_id, branch_name: "master", targets: targets,
                          label: "master", git_ref_type: 2} = request
    assert [ppl_id] == request.prev_ppl_artefact_ids
    assert %Target{name: "stg", pipeline_path: "./stg.yaml", parameter_env_vars: [],
                   auto_trigger_on: [AutoTriggerCond.new(result: "passed",
                   branch: ["mast.", "xyz"])], auto_promote_when: "", deployment_target: ""}
                == Enum.at(targets, 0)
    assert %Target{name: "prod", pipeline_path: "./prod.yaml", auto_trigger_on: [],
                   auto_promote_when: "", deployment_target: "", parameter_env_vars:
                     [%ParamEnvVar{name: "TEST", options: ["1", "2"], required: true,
                                   default_value: "9", description: ""},
                     %ParamEnvVar{name: "TEST_2", options: [], required: false,
                                   default_value: "", description: "asfef"}]}
                == Enum.at(targets, 1)
    assert %Target{name: "artifacts_storage", pipeline_path: "./art_store.yaml", parameter_env_vars: [],
                   auto_trigger_on: [], auto_promote_when: "result = 'passed'", deployment_target: ""}
                == Enum.at(targets, 2)
  end

  # PipelineDone

  test "when switch_id is nil form_pipeline_done_request() returnes {:ok, :switch_not_defined}" do
    assert {:ok, :switch_not_defined} == RequestFormatter.form_pipeline_done_request(nil, "passed", "")
  end

  test "form_pipeline_done_request() returns valid proto message when given valid params" do
    switch_id = UUID.uuid4()
    result = "failed"
    result_reason = "test"

    assert {:ok, request} = RequestFormatter.form_pipeline_done_request(switch_id, result, result_reason)
    assert %PipelineDoneRequest{switch_id: ^switch_id, result: ^result,
                                result_reason: ^result_reason} = request
  end

end
