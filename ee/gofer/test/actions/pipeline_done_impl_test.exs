defmodule Gofer.Actions.PipelineDoneImpl.Test do
  use ExUnit.Case

  import Ecto.Query

  alias Gofer.DeploymentTrigger.Model.DeploymentTriggerQueries
  alias Gofer.Actions
  alias Gofer.Target.Model.TargetQueries
  alias Gofer.Switch.Model.SwitchQueries
  alias Gofer.SwitchTrigger.Model.{SwitchTrigger, SwitchTriggerQueries}
  alias Gofer.TargetTrigger.Model.TargetTriggerQueries
  alias Gofer.Switch.Engine.SwitchSupervisor, as: SSupervisor
  alias Gofer.SwitchTrigger.Engine.SwitchTriggerSupervisor, as: STSupervisor
  alias Gofer.TargetTrigger.Engine.TargetTriggerSupervisor, as: TTSupervisor
  alias Test.Helpers
  alias Gofer.EctoRepo, as: Repo
  alias Util.Proto

  alias InternalApi.Repository.{
    ListResponse,
    GetChangedFilePathsResponse
  }

  @grpc_port 50061
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

    switch_def = %{
      "id" => UUID.uuid4(),
      "ppl_id" => UUID.uuid4(),
      "project_id" => "p1",
      "prev_ppl_artefact_ids" => [],
      "branch_name" => "master",
      "label" => "master",
      "git_ref_type" => "branch",
      "pr_base" => "",
      "commit_sha" => "1234",
      "working_dir" => ".semaphore/",
      "commit_range" => "123...456",
      "yml_file_name" => "semaphore.yml"
    }

    target_1 = %{
      "name" => "staging",
      "pipeline_path" => "./stg.yml",
      "auto_trigger_on" => [
        %{"result" => "passed", "branch" => ["mast.", "xyz"]},
        %{"result" => "canceled", "label_patterns" => ["cancel-"]},
        %{"result" => "stopped", "labels" => ["stop-branch"]}
      ],
      "parameter_env_vars" => %{
        "EV1" => %{"name" => "EV1", "options" => ["0", "1"]},
        "EV2" => %{"name" => "EV2", "default_value" => "2", "description" => "asdf"},
        "EV3" => %{"name" => "EV3", "default_value" => "3"}
      }
    }

    target_2 = %{"name" => "prod", "pipeline_path" => "./prod.yml"}

    target_3 = %{
      "name" => "store artifacts",
      "pipeline_path" => "./store.yml",
      "auto_promote_when" => "tag =~ 'v1.*' and result = 'passed'"
    }

    target_4 = %{
      "name" => "change_in",
      "pipeline_path" => "./change_in.yml",
      "auto_promote_when" => "change_in(['/test-dir/'])"
    }

    target_5 = %{
      "name" => "Canary1",
      "pipeline_path" => "./canary.yml",
      "deployment_target" => "canary"
    }

    target_6 = %{
      "name" => "Canary2",
      "pipeline_path" => "./canary.yml",
      "auto_trigger_on" => [
        %{"result" => "passed", "branch" => ["mast.", "xyz"]},
        %{"result" => "canceled", "label_patterns" => ["cancel-"]},
        %{"result" => "stopped", "labels" => ["stop-branch"]}
      ],
      "deployment_target" => "canary"
    }

    targets_defs = [target_1, target_2, target_3, target_4, target_5, target_6]

    Gofer.EctoRepo.insert!(%Gofer.Deployment.Model.Deployment{
      id: Ecto.UUID.generate(),
      name: "canary",
      organization_id: UUID.uuid4(),
      project_id: "p1",
      created_by: UUID.uuid4(),
      updated_by: UUID.uuid4(),
      unique_token: UUID.uuid4(),
      state: :FINISHED,
      result: :SUCCESS
    })

    start_supervised!(SSupervisor)
    start_supervised!(STSupervisor)
    start_supervised!(TTSupervisor)

    {:ok, %{switch_def: switch_def, targets_defs: targets_defs}}
  end

  # Pipeline done

  test "return NOT_FOUND when there is no switch with given switch_id" do
    id = UUID.uuid4()
    assert {:ok, {:NOT_FOUND, message}} = Actions.proces_ppl_done_request(id, "passed", "")
    assert message == "Switch with id #{id} not found."
  end

  test "pipeline_done call is idempotent for same result and result_reason", ctx do
    Helpers.use_test_plumber_service(@grpc_port)
    Helpers.test_plumber_service_schedule_response("valid")

    assert {:ok, switch} = SwitchQueries.insert(ctx.switch_def)

    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(0), switch)
    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(1), switch)
    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(2), switch)

    assert {:ok, {:OK, message}} = Actions.proces_ppl_done_request(switch.id, "passed", "")
    assert message == "Pipeline execution result received and processed."

    request_token = switch.id <> "-" <> "auto"
    assert {:ok, switch_trigger_1} = SwitchTriggerQueries.get_by_request_token(request_token)

    assert {:ok, {:OK, message}} = Actions.proces_ppl_done_request(switch.id, "passed", "")
    assert message == "Pipeline execution result received and processed."

    assert {:ok, switch_trigger_2} = SwitchTriggerQueries.get_by_request_token(request_token)

    assert NaiveDateTime.compare(switch_trigger_1.inserted_at, switch_trigger_2.inserted_at) ==
             :eq
  end

  test "pipeline_done call is idempotent with deployment triggers for same result and result_reason",
       ctx do
    Helpers.use_test_plumber_service(@grpc_port)
    Helpers.test_plumber_service_schedule_response("valid")
    mock_deployment_triggers_supervisor()

    assert {:ok, switch} = SwitchQueries.insert(ctx.switch_def)

    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(0), switch)
    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(1), switch)
    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(5), switch)

    assert {:ok, {:OK, message}} = Actions.proces_ppl_done_request(switch.id, "passed", "")
    assert message == "Pipeline execution result received and processed."

    target_name_md5 =
      ctx.targets_defs
      |> Enum.at(5)
      |> Map.get("name")
      |> :erlang.md5()
      |> Base.encode16(case: :lower)

    request_token = switch.id <> "-" <> target_name_md5 <> "-auto"
    assert {:ok, dpl_trigger_1} = DeploymentTriggerQueries.find_by_request_token(request_token)

    assert {:ok, {:OK, message}} = Actions.proces_ppl_done_request(switch.id, "passed", "")
    assert message == "Pipeline execution result received and processed."

    assert {:ok, dpl_trigger_2} = DeploymentTriggerQueries.find_by_request_token(request_token)

    assert NaiveDateTime.compare(dpl_trigger_1.inserted_at, dpl_trigger_2.inserted_at) == :eq
  end

  test "updates switch, creates valid switch_trigger and starts switch_trigger_process when given valid params",
       ctx do
    Helpers.use_test_plumber_service(@grpc_port)
    Helpers.test_plumber_service_schedule_response("valid")

    assert {:ok, switch} = SwitchQueries.insert(ctx.switch_def)

    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(0), switch)
    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(1), switch)
    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(2), switch)

    ts_before = DateTime.utc_now()

    assert {:ok, {:OK, message}} = Actions.proces_ppl_done_request(switch.id, "passed", "")
    assert message == "Pipeline execution result received and processed."

    assert {:ok, switch_trigger} =
             assert_switch_trigger_valid(switch.id, "passed", ["staging"], ts_before)

    wait_for_triggers_to_finish(
      switch.id,
      switch_trigger.id,
      switch_trigger.triggered_at,
      "staging"
    )
  end

  test "target with auto trigger with labels field is triggered when pipeline_done request is processed",
       ctx do
    Helpers.use_test_plumber_service(@grpc_port)
    Helpers.test_plumber_service_schedule_response("valid")

    assert {:ok, switch} =
             ctx.switch_def |> Map.put("branch_name", "stop-branch") |> SwitchQueries.insert()

    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(0), switch)
    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(1), switch)
    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(2), switch)

    ts_before = DateTime.utc_now()

    assert {:ok, {:OK, message}} = Actions.proces_ppl_done_request(switch.id, "stopped", "")
    assert message == "Pipeline execution result received and processed."

    assert {:ok, switch_trigger} =
             assert_switch_trigger_valid(switch.id, "stopped", ["staging"], ts_before)

    wait_for_triggers_to_finish(
      switch.id,
      switch_trigger.id,
      switch_trigger.triggered_at,
      "staging"
    )
  end

  test "target with auto trigger with label_patternss field is triggered when pipeline_done request is processed",
       ctx do
    Helpers.use_test_plumber_service(@grpc_port)
    Helpers.test_plumber_service_schedule_response("valid")

    assert {:ok, switch} =
             ctx.switch_def |> Map.put("branch_name", "cancel-123") |> SwitchQueries.insert()

    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(0), switch)
    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(1), switch)
    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(2), switch)

    ts_before = DateTime.utc_now()

    assert {:ok, {:OK, message}} = Actions.proces_ppl_done_request(switch.id, "canceled", "")
    assert message == "Pipeline execution result received and processed."

    assert {:ok, switch_trigger} =
             assert_switch_trigger_valid(switch.id, "canceled", ["staging"], ts_before)

    wait_for_triggers_to_finish(
      switch.id,
      switch_trigger.id,
      switch_trigger.triggered_at,
      "staging"
    )
  end

  test "target with auto_promote_when field is triggered when pipeline_done request is processed",
       ctx do
    Helpers.use_test_plumber_service(@grpc_port)
    Helpers.test_plumber_service_schedule_response("valid")

    assert {:ok, switch} =
             ctx.switch_def
             |> Map.merge(%{
               "label" => "v1.5",
               "git_ref_type" => "tag",
               "branch_name" => "refs/tags/v1.5"
             })
             |> SwitchQueries.insert()

    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(0), switch)
    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(1), switch)
    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(2), switch)

    ts_before = DateTime.utc_now()

    assert {:ok, {:OK, message}} = Actions.proces_ppl_done_request(switch.id, "passed", "")
    assert message == "Pipeline execution result received and processed."

    assert {:ok, switch_trigger} =
             assert_switch_trigger_valid(switch.id, "passed", ["store artifacts"], ts_before)

    wait_for_triggers_to_finish(
      switch.id,
      switch_trigger.id,
      switch_trigger.triggered_at,
      "store artifacts"
    )
  end

  test "target with change_in in auto_promote_when field is triggered when pipeline_done request is processed",
       ctx do
    Helpers.use_test_plumber_service(@grpc_port)
    Helpers.test_plumber_service_schedule_response("valid")
    System.put_env(@mock_server_url_env_name, "localhost:#{@grpc_port}")

    setup_mock_repo_hub_responses()

    assert {:ok, switch} =
             ctx.switch_def
             |> Map.merge(%{
               "label" => "dev",
               "git_ref_type" => "pr",
               "pr_sha" => "pr_sha",
               "branch_name" => "dev",
               "pr_base" => "pr_base"
             })
             |> SwitchQueries.insert()

    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(0), switch)
    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(1), switch)
    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(2), switch)
    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(3), switch)

    ts_before = DateTime.utc_now()

    assert {:ok, {:OK, message}} = Actions.proces_ppl_done_request(switch.id, "passed", "")
    assert message == "Pipeline execution result received and processed."

    assert {:ok, switch_trigger} =
             assert_switch_trigger_valid(switch.id, "passed", ["change_in"], ts_before)

    wait_for_triggers_to_finish(
      switch.id,
      switch_trigger.id,
      switch_trigger.triggered_at,
      "change_in"
    )

    GrpcMock.verify!(RepoHubMock)
  end

  test "target with deployment target is triggered when pipeline_done request is processed",
       ctx do
    Helpers.use_test_plumber_service(@grpc_port)
    Helpers.test_plumber_service_schedule_response("valid")
    mock_deployment_triggers_supervisor()

    assert {:ok, switch} = SwitchQueries.insert(ctx.switch_def)

    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(0), switch)
    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(1), switch)
    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(5), switch)

    ts_before = DateTime.utc_now()

    assert {:ok, {:OK, message}} = Actions.proces_ppl_done_request(switch.id, "passed", "")
    assert message == "Pipeline execution result received and processed."

    assert {:ok, switch_trigger} =
             assert_switch_trigger_valid(switch.id, "passed", ["staging"], ts_before)

    assert {:ok, %{request_token: dpl_request_token}} =
             assert_deployment_trigger_valid(switch.id, "passed", "Canary2", ts_before)

    wait_for_triggers_to_finish(
      switch.id,
      switch_trigger.id,
      switch_trigger.triggered_at,
      "staging"
    )

    assert {:ok, [{^dpl_request_token, _pid}]} =
             Test.MockDynamicSupervisor.get_calls(Gofer.DeploymentTrigger.Engine.Supervisor)
  end

  test "target with deployment target is not triggered when pipeline_done request is processed",
       ctx do
    Helpers.use_test_plumber_service(@grpc_port)
    Helpers.test_plumber_service_schedule_response("valid")
    mock_deployment_triggers_supervisor()

    assert {:ok, switch} = SwitchQueries.insert(ctx.switch_def)

    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(0), switch)
    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(1), switch)
    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(4), switch)

    ts_before = DateTime.utc_now()

    assert {:ok, {:OK, message}} = Actions.proces_ppl_done_request(switch.id, "passed", "")
    assert message == "Pipeline execution result received and processed."

    assert {:ok, switch_trigger} =
             assert_switch_trigger_valid(switch.id, "passed", ["staging"], ts_before)

    target_name_md5 = "Canary1" |> :erlang.md5() |> Base.encode16(case: :lower)
    request_token = switch.id <> "-" <> target_name_md5 <> "-auto"
    assert {:error, :not_found} = DeploymentTriggerQueries.find_by_request_token(request_token)

    wait_for_triggers_to_finish(
      switch.id,
      switch_trigger.id,
      switch_trigger.triggered_at,
      "staging"
    )
  end

  defp setup_mock_repo_hub_responses() do
    RepoHubMock
    |> GrpcMock.expect(:list, fn _req, _ ->
      %{repositories: [%{id: "r1"}]} |> Proto.deep_new!(ListResponse)
    end)
    |> GrpcMock.expect(:get_changed_file_paths, fn request, _ ->
      %{base_rev: base, head_rev: head, comparison_type: comp_type} = request
      assert base.reference == "refs/heads/pr_base"
      assert head.commit_sha == "pr_sha"
      assert comp_type == :HEAD_TO_MERGE_BASE

      changes = ["test-dir/1.txt", "something/other"]

      %{changed_file_paths: changes} |> Proto.deep_new!(GetChangedFilePathsResponse)
    end)
  end

  defp wait_for_triggers_to_finish(switch_id, sw_tg_id, triggered_at, target_name) do
    args = [SwitchTriggerQueries, :get_by_id, [sw_tg_id]]
    Helpers.assert_finished_for_less_than(Helpers, :entity_processed?, args, 3_000)

    assert {:ok, target_trigger} = TargetTriggerQueries.get_by_id_and_name(sw_tg_id, target_name)
    assert target_trigger.switch_id == switch_id
    assert {:ok, _} = target_trigger.schedule_request_token |> UUID.info()

    args = [TargetTriggerQueries, :get_by_id_and_name, [sw_tg_id, target_name]]
    Helpers.assert_finished_for_less_than(Helpers, :entity_processed?, args, 3_000)

    assert {:ok, target_trigger} = TargetTriggerQueries.get_by_id_and_name(sw_tg_id, target_name)
    assert {:ok, _} = target_trigger.scheduled_ppl_id |> UUID.info()
    refute is_nil(target_trigger.scheduled_at)
    assert target_trigger.processing_result == "passed"
    assert DateTime.compare(triggered_at, target_trigger.scheduled_at) == :lt
  end

  defp assert_switch_trigger_valid(switch_id, ppl_result, targets, ts_before) do
    assert {:ok, switch} = SwitchQueries.get_by_id(switch_id)
    assert switch.ppl_result == ppl_result

    request_token = switch_id <> "-" <> "auto"
    assert {:ok, switch_trigger} = SwitchTriggerQueries.get_by_request_token(request_token)
    assert switch_trigger.switch_id == switch_id
    assert switch_trigger.request_token == request_token
    assert switch_trigger.target_names == targets
    assert switch_trigger.triggered_by == "Pipeline Done request"
    refute is_nil(switch_trigger.triggered_at)
    assert DateTime.compare(switch_trigger.triggered_at, ts_before) == :gt
    assert DateTime.compare(switch_trigger.triggered_at, DateTime.utc_now()) == :lt
    assert switch_trigger.auto_triggered == true
    assert switch_trigger.override == false
    assert_default_env_vars_are_set(switch_trigger.env_vars_for_target, targets)

    {:ok, switch_trigger}
  end

  defp assert_deployment_trigger_valid(switch_id, ppl_result, target, ts_before) do
    assert {:ok, switch} = SwitchQueries.get_by_id(switch_id)
    assert switch.ppl_result == ppl_result

    target_name_md5 = target |> :erlang.md5() |> Base.encode16(case: :lower)
    request_token = switch.id <> "-" <> target_name_md5 <> "-auto"

    assert {:ok, deployment_trigger} =
             DeploymentTriggerQueries.find_by_request_token(request_token)

    assert deployment_trigger.switch_id == switch_id
    assert deployment_trigger.request_token == request_token

    assert deployment_trigger.switch_trigger_params["switch_id"] == switch_id
    assert deployment_trigger.switch_trigger_params["request_token"] == request_token
    assert deployment_trigger.switch_trigger_params["target_names"] == [target]
    assert deployment_trigger.switch_trigger_params["triggered_by"] == "Pipeline Done request"
    assert deployment_trigger.switch_trigger_params["auto_triggered"] == true
    assert deployment_trigger.switch_trigger_params["override"] == false

    refute is_nil(deployment_trigger.triggered_at)
    assert DateTime.compare(deployment_trigger.triggered_at, ts_before) == :gt
    assert DateTime.compare(deployment_trigger.triggered_at, DateTime.utc_now()) == :lt

    {:ok, deployment_trigger}
  end

  defp assert_default_env_vars_are_set(env_vars, targets) do
    if Enum.member?(targets, "staging") do
      assert env_vars["staging"] |> length() == 2
      assert env_vars["staging"] |> Enum.member?(%{"name" => "EV2", "value" => "2"})
      assert env_vars["staging"] |> Enum.member?(%{"name" => "EV3", "value" => "3"})
    end
  end

  test "switch_trigger is not inserted and process is not started if auto_trigger_on.result != ppl_result",
       ctx do
    assert {:ok, switch} = SwitchQueries.insert(ctx.switch_def)

    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(0), switch)
    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(1), switch)
    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(2), switch)

    # auto_trigger_on.result  is "passed"
    assert {:ok, {:OK, message}} = Actions.proces_ppl_done_request(switch.id, "failed", "")
    assert message == "Pipeline execution result received and processed."

    assert [] == SwitchTrigger |> where(switch_id: ^switch.id) |> Repo.all()
  end

  test "switch_trigger is not inserted and process is not started if auto-condition branch != branch_name",
       ctx do
    assert {:ok, switch} = SwitchQueries.insert(ctx.switch_def)
    # branch_name is "master"
    conditions = [%{"result" => "passed", "branch" => ["123", "xyz"]}]
    target_1 = ctx.targets_defs |> Enum.at(0) |> Map.put("auto_trigger_on", conditions)

    assert {:ok, _target} = TargetQueries.insert(target_1, switch)
    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(1), switch)
    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(2), switch)

    assert {:ok, {:OK, message}} = Actions.proces_ppl_done_request(switch.id, "passed", "")
    assert message == "Pipeline execution result received and processed."

    assert [] == SwitchTrigger |> where(switch_id: ^switch.id) |> Repo.all()
  end

  test "returns :RESULT_CHANGED when it is called for switch which already has defined result",
       ctx do
    assert {:ok, switch} = SwitchQueries.insert(ctx.switch_def)

    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(0), switch)
    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(1), switch)
    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(2), switch)

    assert {:ok, {:OK, _message}} = Actions.proces_ppl_done_request(switch.id, "passed", "")

    assert {:ok, response} = Actions.proces_ppl_done_request(switch.id, "failed", "")
    assert {:RESULT_CHANGED, message} = response
    assert message == "Previous result: passed, new result: failed."

    assert {:ok, switch} = SwitchQueries.get_by_id(switch.id)
    assert switch.ppl_result == "passed"
  end

  test "returns :RESULT_REASON_CHANGED when it is called for switch which already has defined result_reason",
       ctx do
    assert {:ok, switch} = SwitchQueries.insert(ctx.switch_def)

    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(0), switch)
    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(1), switch)
    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(2), switch)

    assert {:ok, {:OK, _message}} = Actions.proces_ppl_done_request(switch.id, "failed", "test")

    assert {:ok, response} = Actions.proces_ppl_done_request(switch.id, "failed", "malformed")
    assert {:RESULT_REASON_CHANGED, message} = response
    assert message == "Previous result_reason: test, new result_reason: malformed."

    assert {:ok, switch} = SwitchQueries.get_by_id(switch.id)
    assert switch.ppl_result == "failed"
    assert switch.ppl_result_reason == "test"
  end

  defp mock_deployment_triggers_supervisor() do
    alias Gofer.DeploymentTrigger.Model.DeploymentTriggerQueries, as: TriggerQueries

    start_supervised!(
      {Test.MockDynamicSupervisor,
       [
         name: Gofer.DeploymentTrigger.Engine.Supervisor,
         call_extractor: fn
           {switch, deployment, params} ->
             case TriggerQueries.create(switch, deployment, params) do
               {:ok, trigger} -> trigger.request_token
               {:error, _reason} -> params["request_token"]
             end
         end
       ]}
    )
  end
end
