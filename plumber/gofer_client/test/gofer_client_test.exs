defmodule GoferClient.Test do
  use ExUnit.Case

  setup_all do
    Test.Support.GrpcServerHelper.start_server_with_cleanup(Test.MockGoferService)
  end

  setup %{port: port} do
    Test.Support.GrpcServerHelper.setup_service_url("INTERNAL_API_URL_GOFER", port)
    :ok
  end

  # Create

  test "when promotions definition is valid create response is {:ok, uuid}" do
    use_test_gofer_service()
    test_gofer_service_response("valid")

    stg_target = %{"name" => "stg", "pipeline_file" => "./stg.yaml",
                   "auto_promote_on" => [%{"result" => "passed", "branch" => ["mast.", "xyz"]}]}
    prod_target = %{"name" => "prod", "pipeline_file" => "./prod.yaml"}
    art_store_target = %{"name" => "artifacts_storage", "pipeline_file" => "./art_store.yaml",
                         "auto_promote" => %{"when" => "result = 'passed'"}}
    switch_def = %{"promotions" => [stg_target, prod_target, art_store_target]}

    ref_args =
      %{branch_name: "master", label: "master", git_ref_type: "branch", project_id: "pr1",
        working_dir: "", commit_range: "12sfe...safe2d", commit_sha: "safe2d", pr_base: "",
        yml_file_name: "semaphore.yml", pr_sha: ""}

    ppl_id = UUID.uuid4()
    assert {:ok, response} = GoferClient.create_switch(switch_def, ppl_id, [ppl_id], ref_args)
    assert {:ok, _} = UUID.info(response)
  end

  test 'when promotions are not defined in yml create returnes {:ok, ""}' do
    use_test_gofer_service()
    test_gofer_service_response("valid")

    ref_args =
      %{branch_name: "master", label: "master", git_ref_type: "branch", project_id: "pr1",
        working_dir: "", commit_range: "12sfe...safe2d", commit_sha: "safe2d", pr_base: "",
        yml_file_name: "semaphore.yml", pr_sha: ""}

    ppl_id = UUID.uuid4()
    assert {:ok, ""} == GoferClient.create_switch(%{}, ppl_id, [ppl_id], ref_args)
  end

  test "when create request failes on Gofer, client returnes {:error, gofer_message}" do
    use_test_gofer_service()
    test_gofer_service_response("bad_param")

    stg_target = %{"name" => "prod", "pipeline_file" => "./stg.yaml",
                   "auto_promote_on" => [%{"result" => "passed", "branch" => ["mast.", "xyz"]}]}
    prod_target = %{"name" => "prod", "pipeline_file" => "./prod.yaml"}
    switch_def = %{"promotions" => [stg_target, prod_target]}

    ppl_id = UUID.uuid4()
    ref_args =
      %{branch_name: "master", label: "master", git_ref_type: "branch", project_id: "pr1",
        working_dir: "", commit_range: "12sfe...safe2d", commit_sha: "safe2d", pr_base: "",
        yml_file_name: "semaphore.yml", pr_sha: ""}

    assert {:error, "Error"} == GoferClient.create_switch(switch_def, ppl_id, [ppl_id], ref_args)
  end

  test "when Gofer returnes MALFORMED, client returnes {:error, {:malformed, gofer_message}}" do
    use_test_gofer_service()
    test_gofer_service_response("malformed")

    target = %{"name" => "prod", "pipeline_file" => "./prod.yaml"}
    switch_def = %{"promotions" => [target, target]}

    ppl_id = UUID.uuid4()
    ref_args =
      %{branch_name: "master", label: "master", git_ref_type: "branch", project_id: "pr1",
        working_dir: "", commit_range: "12sfe...safe2d", commit_sha: "safe2d", pr_base: "",
        yml_file_name: "semaphore.yml", pr_sha: ""}

    assert {:error, {:malformed, "Malformed error"}}
           == GoferClient.create_switch(switch_def, ppl_id, [ppl_id], ref_args)
  end

  # Pipeline_done

  test "given vaild params pipeline_done correctly handles :OK response" do
    use_test_gofer_service()
    test_gofer_service_response("valid")

    assert {:ok, message} = GoferClient.pipeline_done(UUID.uuid4(), "passed", "")
    assert message == "Valid message"
  end

  test "pipeline_done returns error when one or more params are not strings" do
    use_test_gofer_service()

    id = UUID.uuid4()
    res = "failed"
    r_r = "test"

    assert {:error, message} = GoferClient.pipeline_done(1, res, r_r)
    assert message == "One or more of these params: #{inspect 1}, #{inspect res} and #{inspect r_r} is not string."

    assert {:error, message} = GoferClient.pipeline_done(id, 1, r_r)
    assert message == "One or more of these params: #{inspect id}, #{inspect 1} and #{inspect r_r} is not string."

    assert {:error, message} = GoferClient.pipeline_done(id, res, 1)
    assert message == "One or more of these params: #{inspect id}, #{inspect res} and #{inspect 1} is not string."

    assert {:error, message} = GoferClient.pipeline_done(1, 1, 1)
    assert message == "One or more of these params: #{inspect 1}, #{inspect 1} and #{inspect 1} is not string."
  end

  test "pipeline_done correctly handles :BAD_PARAM, :RESULT_CHANGED and :NOT_FOUND responses" do
    use_test_gofer_service()

    test_pipeline_done_result_for_response("bad_param")
    test_pipeline_done_result_for_response("not_found")
    test_pipeline_done_result_for_response("result_changed")
    test_pipeline_done_result_for_response("result_reason_changed")
  end

  defp test_pipeline_done_result_for_response(msg_type) do
    test_gofer_service_response(msg_type)

    assert {:error, message} = GoferClient.pipeline_done(UUID.uuid4(), "passed", "")
    assert message == msg_type |> String.upcase()
  end

  test 'when promotions are not defined pipeline_done returnes {:ok, ""}' do
    use_test_gofer_service()
    test_gofer_service_response("valid")

    assert {:ok, ""} == GoferClient.pipeline_done(nil, "passed", "")
  end

  defp use_test_gofer_service(), do: :ok
  defp test_gofer_service_response(value),
    do: Application.put_env(:gofer_client, :test_gofer_service_response, value)

    describe "when promotions are disabled" do
      setup do
        System.put_env("SKIP_PROMOTIONS", "true")
        on_exit(fn -> System.delete_env("SKIP_PROMOTIONS") end)
      end

      test "create_switch call returnes {:ok, \"\"}" do
        use_test_gofer_service()
        test_gofer_service_response("valid")

        stg_target = %{"name" => "stg", "pipeline_file" => "./stg.yaml",
                      "auto_promote_on" => [%{"result" => "passed", "branch" => ["mast.", "xyz"]}]}
        prod_target = %{"name" => "prod", "pipeline_file" => "./prod.yaml"}
        art_store_target = %{"name" => "artifacts_storage", "pipeline_file" => "./art_store.yaml",
                            "auto_promote" => %{"when" => "result = 'passed'"}}
        switch_def = %{"promotions" => [stg_target, prod_target, art_store_target]}

        ref_args =
          %{branch_name: "master", label: "master", git_ref_type: "branch", project_id: "pr1",
            working_dir: "", commit_range: "12sfe...safe2d", commit_sha: "safe2d", pr_base: "",
            yml_file_name: "semaphore.yml", pr_sha: ""}

        ppl_id = UUID.uuid4()
        assert {:ok, ""} == GoferClient.create_switch(switch_def, ppl_id, [ppl_id], ref_args)
      end

      test "pipeline_done call returns {:ok, \"\"}" do
        use_test_gofer_service()
        test_gofer_service_response("valid")

        assert {:ok, ""} == GoferClient.pipeline_done(UUID.uuid4(), "passed", "")
      end
    end
end
