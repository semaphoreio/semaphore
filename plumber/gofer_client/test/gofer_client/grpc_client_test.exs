defmodule GoferClient.GrpcClient.Test do
  use ExUnit.Case

  alias GoferClient.GrpcClient
  alias InternalApi.Gofer.ResponseStatus.ResponseCode
  alias InternalApi.Gofer.{
      Target,
      CreateRequest,
      CreateResponse,
      ResponseStatus,
      PipelineDoneRequest,
      PipelineDoneResponse,
      AutoTriggerCond
  }

  setup_all do
    Test.Support.GrpcServerHelper.start_server_with_cleanup(Test.MockGoferService)
  end

  setup %{port: port} do
    Test.Support.GrpcServerHelper.setup_service_url("INTERNAL_API_URL_GOFER", port)
    :ok
  end

  # Create

  test "send valid create request and receive valid test response" do
    use_test_gofer_service()
    test_gofer_service_response("valid")

    ppl_id = UUID.uuid4()

    target_prod = %Target{name: "prod", pipeline_path: "./prod.yaml", auto_promote_when: "",
                          auto_trigger_on: [], deployment_target: ""}
    target_stg = %Target{name: "stg", pipeline_path: "./stg.yaml", auto_promote_when: "",
      auto_trigger_on: [AutoTriggerCond.new(result: "passed", branch: ["mast.", "xyz"])], deployment_target: ""}

    request = %CreateRequest{pipeline_id: ppl_id, targets: [target_stg, target_prod],
                             prev_ppl_artefact_ids: [ppl_id], branch_name: "master",
                             label: "master", git_ref_type: 0, project_id: "pr1",
                             commit_sha: "hnbni", commit_range: "oujnc...hnbni",
                             working_dir: "svcA/", pr_base: "", pr_sha: "",
                             yml_file_name: "semaphore.yml"}

    assert {:ok, response} = GrpcClient.create_switch({:ok, request})
    assert %CreateResponse{switch_id: id, response_status: %{message: "", code: 0}}
              = response
    assert {:ok, _} = UUID.info(id)
  end

  test "send invalid create request and receive bad param response" do
    use_test_gofer_service()
    test_gofer_service_response("bad_param")

    assert {:ok, response} = GrpcClient.create_switch({:ok, CreateRequest.new()})
    assert %CreateResponse{switch_id: "", response_status: %ResponseStatus{message: "Error", code: 1}}
              == response
  end

  test "skip creating switch if there is no switch definition in yaml file" do
    assert {:ok, :switch_not_defined} = GrpcClient.create_switch({:ok, :switch_not_defined})
  end

  test "create returns error when it is not possible to connect to gofer service" do
    use_non_existing_gofer_service()

    assert {:error, _} = GrpcClient.create_switch({:ok, CreateRequest.new()})
  end

  test "create correctly timeouts if gofer service takes to long to respond" do
    use_test_gofer_service()
    test_gofer_service_response("timeout")

    assert {:error, _} = GrpcClient.create_switch({:ok, CreateRequest.new()})
  end

  # PipelineDone

  test "send valid pipeline_done request and receive valid test response" do
    use_test_gofer_service()
    test_gofer_service_response("valid")

    request = %PipelineDoneRequest{switch_id: UUID.uuid4(), result: "passed", result_reason: ""}

    assert {:ok, response} = GrpcClient.pipeline_done({:ok, request})
    assert %PipelineDoneResponse{response_status: %{message: message, code: 0}}
              = response
    assert message == "Valid message"
  end

  test "bad_param, not_found, result_changed and result_reason_changed responses are received correctly" do
    use_test_gofer_service()

    test_receive_message("bad_param")
    test_receive_message("not_found")
    test_receive_message("result_changed")
    test_receive_message("result_reason_changed")
  end

  defp test_receive_message(msg_type) do
    test_gofer_service_response(msg_type)

    assert {:ok, response} = GrpcClient.pipeline_done({:ok, PipelineDoneRequest.new()})
    assert %PipelineDoneResponse{response_status: %{message: message, code: code}} = response
    assert ResponseCode.key(code) == msg_type |> String.upcase() |> String.to_atom()
    assert message == msg_type |> String.upcase()
  end

  test "skip sending pipeline result if switch is not defined" do
    assert {:ok, :switch_not_defined} = GrpcClient.pipeline_done({:ok, :switch_not_defined})
  end

  test "pipeline_done returns error when it is not possible to connect to gofer service" do
    use_non_existing_gofer_service()

    assert {:error, _} = GrpcClient.pipeline_done({:ok, PipelineDoneRequest.new()})
  end

  test "pipeline_done correctly timeouts if gofer service takes to long to respond" do
    use_test_gofer_service()
    test_gofer_service_response("timeout")

    assert {:error, _} = GrpcClient.pipeline_done({:ok, PipelineDoneRequest.new()})
  end

  # Utility

  defp use_test_gofer_service(), do: :ok

  defp use_non_existing_gofer_service(),
    do: System.put_env("INTERNAL_API_URL_GOFER", "something:12345")

  defp test_gofer_service_response(value),
    do: Application.put_env(:gofer_client, :test_gofer_service_response, value)
end
