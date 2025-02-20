defmodule Gofer.Switch.Engine.SwitchProcess.Test do
  use ExUnit.Case

  alias Gofer.Switch.Engine.SwitchProcess, as: SP
  alias Gofer.Switch.Model.SwitchQueries
  alias Gofer.Target.Model.TargetQueries
  alias Gofer.Deployment.Model.DeploymentQueries
  alias Gofer.SwitchTrigger.Engine.SwitchTriggerSupervisor, as: STSupervisor
  alias Gofer.TargetTrigger.Engine.TargetTriggerSupervisor, as: TTSupervisor
  alias Gofer.SwitchTrigger.Model.SwitchTriggerQueries

  @grpc_port 50058
  @mock_server_url_env_name "REPOHUB_GRPC_URL"

  setup_all do
    GRPC.Server.start([Test.MockPlumberService, RepoHubMock], @grpc_port)

    on_exit(fn ->
      GRPC.Server.stop([Test.MockPlumberService, RepoHubMock])
    end)

    {:ok, %{}}
  end

  setup do
    assert {:ok, _} =
             Ecto.Adapters.SQL.query(Gofer.EctoRepo, "truncate table deployments cascade;")

    assert {:ok, _} = Ecto.Adapters.SQL.query(Gofer.EctoRepo, "truncate table switches cascade;")

    assert {:ok, _} =
             DeploymentQueries.create(
               %{
                 name: "production",
                 organization_id: UUID.uuid4(),
                 project_id: "p1",
                 unique_token: UUID.uuid4(),
                 created_by: UUID.uuid4(),
                 updated_by: UUID.uuid4()
               },
               :no_secret_params
             )

    switch_def = %{
      "id" => UUID.uuid4(),
      "ppl_id" => UUID.uuid4(),
      "project_id" => "p1",
      "label" => "master",
      "git_ref_type" => "branch",
      "pr_base" => "",
      "commit_sha" => "1234",
      "working_dir" => ".semaphore/",
      "commit_range" => "123...456",
      "yml_file_name" => "semaphore.yml",
      "prev_ppl_artefact_ids" => [],
      "branch_name" => "master"
    }

    assert {:ok, switch} = SwitchQueries.insert(switch_def)

    target_1_def = %{
      "name" => "staging",
      "pipeline_path" => "./staging.yml",
      "predefined_env_vars" => %{},
      "deployment_target" => "",
      "auto_trigger_on" => [%{"result" => "passed", "branch" => ["mast.", "xyz"]}]
    }

    target_2_def = %{
      "name" => "prod",
      "pipeline_path" => "./prod.yml",
      "predefined_env_vars" => %{},
      "deployment_target" => "production"
    }

    targets_defs = [target_1_def, target_2_def]

    assert {:ok, target_1} = TargetQueries.insert(target_1_def, switch)
    assert {:ok, target_2} = TargetQueries.insert(target_2_def, switch)
    targets = [target_1, target_2]

    start_supervised!(STSupervisor)
    start_supervised!(TTSupervisor)

    {:ok, %{switch_def: switch_def, switch: switch, targets_defs: targets_defs, targets: targets}}
  end

  test "can not start two SPs for same switch_id", ctx do
    id = Map.get(ctx.switch_def, "id")
    params = {ctx.switch_def, ctx.targets_defs}

    assert {:ok, pid} = SP.start_link({id, params})

    assert {:error, {:already_started, pid_2}} = SP.start_link({id, params})
    assert pid == pid_2
  end

  test "SP exits gracefully when there is no switch in db" do
    state = %{id: UUID.uuid4()}
    assert {:stop, :normal, state} == SP.handle_info(:describe_pipeline, state)
  end

  test "SP starts STP when ppl result is already stored but STP was not started", ctx do
    use_test_plumber_service()
    test_plumber_service_describe_response("passed")

    assert {:ok, switch} =
             SwitchQueries.update(ctx.switch, %{"ppl_done" => true, "ppl_result" => "passed"})

    request_token = switch.id <> "-auto"

    assert {:error, "Switch_trigger with request_token #{request_token} not found"} ==
             SwitchTriggerQueries.get_by_request_token(request_token)

    timestamp_before = DateTime.utc_now()

    state = %{id: switch.id}
    assert {:stop, :normal, state} == SP.handle_info(:describe_pipeline, state)

    assert {:ok, switch} = SwitchQueries.get_by_id(switch.id)
    updated_at = DateTime.from_naive!(switch.updated_at, "Etc/UTC")
    assert DateTime.compare(updated_at, timestamp_before) == :lt

    assert {:ok, switch_trigger} = SwitchTriggerQueries.get_by_request_token(request_token)
    assert switch_trigger.switch_id == switch.id
    assert ["staging"] == switch_trigger.target_names
    assert switch_trigger.auto_triggered == true
    assert DateTime.compare(switch_trigger.triggered_at, timestamp_before) == :gt
    assert DateTime.compare(switch_trigger.triggered_at, DateTime.utc_now()) == :lt
  end

  test "SP calls Gofer.describe for pipeline, stores ppl_result and starts STP for auto targets when pipeline is done",
       ctx do
    use_test_plumber_service()
    test_plumber_service_describe_response("passed")

    timestamp_before = DateTime.utc_now()

    state = %{id: ctx.switch.id}
    assert {:stop, :normal, state} == SP.handle_info(:describe_pipeline, state)

    assert {:ok, switch} = SwitchQueries.get_by_id(ctx.switch.id)
    assert switch.ppl_done == true
    assert switch.ppl_result == "passed"

    request_token = switch.id <> "-auto"
    assert {:ok, switch_trigger} = SwitchTriggerQueries.get_by_request_token(request_token)
    assert switch_trigger.switch_id == switch.id
    assert ["staging"] == switch_trigger.target_names
    assert switch_trigger.auto_triggered == true
    assert DateTime.compare(switch_trigger.triggered_at, timestamp_before) == :gt
    assert DateTime.compare(switch_trigger.triggered_at, DateTime.utc_now()) == :lt
  end

  test "SP does not store ppl_result if starting STP failed due to change_in issues", ctx do
    use_test_plumber_service()
    test_plumber_service_describe_response("passed")

    System.put_env(@mock_server_url_env_name, "localhost:#{@grpc_port}")

    RepoHubMock
    |> GrpcMock.expect(:list, fn req, _ ->
      raise GRPC.RPCError,
        status: :not_found,
        message: "The repositories for project '#{req.project_id}' are not found."
    end)

    assert {:ok, switch} =
             ctx.switch_def
             |> Map.merge(%{
               "label" => "dev",
               "git_ref_type" => "pr",
               "pr_sha" => "pr_sha",
               "id" => UUID.uuid4(),
               "pr_base" => "pr_base",
               "branch_name" => "dev",
               "ppl_id" => UUID.uuid4()
             })
             |> SwitchQueries.insert()

    target = %{
      "name" => "change_in",
      "pipeline_path" => "./change_in.yml",
      "auto_promote_when" => "change_in(['/test-dir/'])"
    }

    assert {:ok, _target} = TargetQueries.insert(target, switch)

    state = %{id: switch.id}
    assert {:stop, :restart, state} == SP.handle_info(:describe_pipeline, state)

    assert {:ok, switch} = SwitchQueries.get_by_id(switch.id)
    assert switch.ppl_done == false
    assert switch.ppl_result == nil

    request_token = switch.id <> "-auto"
    assert {:error, message} = SwitchTriggerQueries.get_by_request_token(request_token)
    assert message == "Switch_trigger with request_token #{request_token} not found"

    GrpcMock.verify!(RepoHubMock)
  end

  test "SP gracefully exits without starting a STP when deadline for auto-triggering is reached",
       ctx do
    use_test_plumber_service()
    test_plumber_service_describe_response("passed")

    old_deadline = Application.get_env(:gofer, :auto_trigger_deadline)
    Application.put_env(:gofer, :auto_trigger_deadline, -100)

    state = %{id: ctx.switch.id}
    assert {:stop, :normal, state} == SP.handle_info(:describe_pipeline, state)

    assert {:ok, switch} = SwitchQueries.get_by_id(ctx.switch.id)
    assert switch.ppl_done == true
    assert switch.ppl_result == "passed"

    request_token = switch.id <> "-auto"
    assert {:error, message} = SwitchTriggerQueries.get_by_request_token(request_token)
    assert message == "Switch_trigger with request_token #{request_token} not found"

    Application.put_env(:gofer, :auto_trigger_deadline, old_deadline)
  end

  test "SP schedules next check of pipelines state when pipeline is not done", ctx do
    use_test_plumber_service()
    test_plumber_service_describe_response("running")

    Application.put_env(:gofer, :pipeline_describe_pool_period, 100)

    state = %{id: ctx.switch.id}
    assert {:noreply, state} == SP.handle_info(:describe_pipeline, state)

    assert_receive(
      :describe_pipeline,
      500,
      "Describing pipelines state and result was not rescheduled."
    )
  end

  defp use_test_plumber_service(),
    do: Application.put_env(:gofer, :plumber_grpc_url, "localhost:#{inspect(@grpc_port)}")

  defp test_plumber_service_describe_response(value),
    do: Application.put_env(:gofer, :test_plumber_service_describe_response, value)
end
