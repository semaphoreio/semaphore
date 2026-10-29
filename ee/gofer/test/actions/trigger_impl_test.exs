defmodule Gofer.Actions.TriggerImplTest do
  use ExUnit.Case

  import Ecto.Query

  alias Gofer.DeploymentTrigger.Model.DeploymentTrigger
  alias Gofer.Deployment.Model.DeploymentQueries
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

  @grpc_port 50062

  setup_all do
    GRPC.Server.start(Test.MockPlumberService, @grpc_port)

    on_exit(fn ->
      GRPC.Server.stop(Test.MockPlumberService)
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
      "project_id" => "project1",
      "git_ref_type" => "branch",
      "label" => "master",
      "prev_ppl_artefact_ids" => [],
      "branch_name" => "master"
    }

    target_1 = %{
      "name" => "staging",
      "pipeline_path" => "./stg.yml",
      "parameter_env_vars" => %{},
      "auto_trigger_on" => [%{"result" => "passed", "branch" => ["mast.", "xyz"]}]
    }

    target_2 = %{"name" => "prod", "pipeline_path" => "./prod.yml", "parameter_env_vars" => %{}}
    targets_defs = [target_1, target_2]

    dpl_def = %{
      "name" => "production",
      "organization_id" => UUID.uuid4(),
      "project_id" => "project1",
      "unique_token" => UUID.uuid4(),
      "created_by" => UUID.uuid4(),
      "updated_by" => UUID.uuid4(),
      "subject_rules" => [%{"type" => "USER", "subject_id" => "user1"}],
      "object_rules" => [%{"type" => "BRANCH", "match_mode" => "EXACT", "pattern" => "master"}]
    }

    encrypted_secret = %{
      requester_id: UUID.uuid4(),
      unique_token: UUID.uuid4(),
      key_id: DateTime.utc_now() |> DateTime.to_unix() |> to_string(),
      aes256_key: "asdfghjkl",
      init_vector: "asdfghjkl",
      payload: "qwertyuiopasdfghjklzxcvbnm"
    }

    start_supervised!(SSupervisor)
    start_supervised!(STSupervisor)
    start_supervised!(TTSupervisor)

    {:ok,
     %{
       dpl_def: dpl_def,
       encrypted_secret: encrypted_secret,
       switch_def: switch_def,
       targets_defs: targets_defs
     }}
  end

  # Trigger

  test "trigger() returns NOT_FOUND when there is no switch with given switch_id" do
    request = %{
      switch_id: UUID.uuid4(),
      target_name: "prod",
      triggered_by: "user1",
      override: false,
      request_token: UUID.uuid4(),
      env_variables: [%{name: "Test", value: "1"}]
    }

    assert {:ok, {:NOT_FOUND, message}} = Actions.trigger(request)
    assert message == "Switch with id #{request.switch_id} not found."
  end

  test "trigger() returns NOT_FOUND when switch with given id has no target with target_name",
       ctx do
    assert {:ok, switch} = SwitchQueries.insert(ctx.switch_def)

    request = %{
      switch_id: switch.id,
      target_name: "not-existing-target",
      triggered_by: "user1",
      override: false,
      request_token: UUID.uuid4(),
      env_variables: [%{name: "Test", value: "1"}]
    }

    assert {:ok, {:NOT_FOUND, message}} = Actions.trigger(request)

    assert message ==
             "Target for switch: #{request.switch_id} with name: #{request.target_name} not found"
  end

  test "trigger() returns error when wrong parameter_env_vars option value is passed", ctx do
    Helpers.use_test_plumber_service(@grpc_port)
    Helpers.test_plumber_service_schedule_response("valid")

    assert {:ok, switch} = SwitchQueries.insert(ctx.switch_def)

    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(0), switch)

    env_vars = %{"Test" => %{"name" => "Test", "options" => ["a", "b"]}}
    target_2 = ctx.targets_defs |> Enum.at(1) |> Map.put("parameter_env_vars", env_vars)

    assert {:ok, _target} = TargetQueries.insert(target_2, switch)

    request = %{
      switch_id: switch.id,
      target_name: "prod",
      triggered_by: "user1",
      override: true,
      request_token: UUID.uuid4(),
      env_variables: [%{name: "Test", value: "1"}]
    }

    assert {:error, message} = Actions.trigger(request)
    assert message == "Value '1' of parameter 'Test' is not one of predefined options."
  end

  test "trigger() when default value of parameter which is not in options is passed in request",
       ctx do
    Helpers.use_test_plumber_service(@grpc_port)
    Helpers.test_plumber_service_schedule_response("valid")

    assert {:ok, switch} = SwitchQueries.insert(ctx.switch_def)

    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(0), switch)

    env_vars = %{"Test" => %{"name" => "Test", "options" => ["a", "b"], "default_value" => "c"}}
    target_2 = ctx.targets_defs |> Enum.at(1) |> Map.put("parameter_env_vars", env_vars)

    assert {:ok, _target} = TargetQueries.insert(target_2, switch)

    request = %{
      switch_id: switch.id,
      target_name: "prod",
      triggered_by: "user1",
      override: true,
      request_token: UUID.uuid4(),
      env_variables: [%{name: "Test", value: "c"}]
    }

    assert {:ok, {:OK, message}} = Actions.trigger(request)
    assert message == "Target trigger request recorded."

    assert {:ok, switch_trigger} =
             SwitchTriggerQueries.get_by_request_token(request.request_token)

    assert switch_trigger.env_vars_for_target == %{
             "prod" => [%{"name" => "Test", "value" => "c"}]
           }
  end

  test "trigger() returns error when value is passed for parameter which is not defined in yml",
       ctx do
    Helpers.use_test_plumber_service(@grpc_port)
    Helpers.test_plumber_service_schedule_response("valid")

    assert {:ok, switch} = SwitchQueries.insert(ctx.switch_def)

    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(0), switch)
    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(1), switch)

    request = %{
      switch_id: switch.id,
      target_name: "prod",
      triggered_by: "user1",
      override: true,
      request_token: UUID.uuid4(),
      env_variables: [%{name: "Test", value: "c"}]
    }

    assert {:error, message} = Actions.trigger(request)
    assert message == "Parameter 'Test' is not defined in promotion's yml definition."
  end

  test "trigger() returns error when value is not passed for required parameter env var", ctx do
    Helpers.use_test_plumber_service(@grpc_port)
    Helpers.test_plumber_service_schedule_response("valid")

    assert {:ok, switch} = SwitchQueries.insert(ctx.switch_def)

    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(0), switch)

    env_vars = %{"Test" => %{"name" => "Test", "options" => ["a", "b"], "required" => true}}
    target_2 = ctx.targets_defs |> Enum.at(1) |> Map.put("parameter_env_vars", env_vars)

    assert {:ok, _target} = TargetQueries.insert(target_2, switch)

    request = %{
      switch_id: switch.id,
      target_name: "prod",
      triggered_by: "user1",
      override: true,
      request_token: UUID.uuid4(),
      env_variables: []
    }

    assert {:error, message} = Actions.trigger(request)
    assert message == "Missing value for required parameter 'Test'."
  end

  test "trigger() default values for parameters are set when they are not passed in request",
       ctx do
    Helpers.use_test_plumber_service(@grpc_port)
    Helpers.test_plumber_service_schedule_response("valid")

    assert {:ok, switch} = SwitchQueries.insert(ctx.switch_def)

    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(0), switch)

    env_vars = %{"Test" => %{"name" => "Test", "options" => ["a", "b"], "default_value" => "c"}}
    target_2 = ctx.targets_defs |> Enum.at(1) |> Map.put("parameter_env_vars", env_vars)

    assert {:ok, _target} = TargetQueries.insert(target_2, switch)

    request = %{
      switch_id: switch.id,
      target_name: "prod",
      triggered_by: "user1",
      override: true,
      request_token: UUID.uuid4(),
      env_variables: []
    }

    assert {:ok, {:OK, message}} = Actions.trigger(request)
    assert message == "Target trigger request recorded."

    assert {:ok, switch_trigger} =
             SwitchTriggerQueries.get_by_request_token(request.request_token)

    assert switch_trigger.env_vars_for_target == %{
             "prod" => [%{"name" => "Test", "value" => "c"}]
           }
  end

  test "trigger() when target is bound to non-existent deployment target then returns errors",
       ctx do
    Helpers.use_test_plumber_service(@grpc_port)
    Helpers.test_plumber_service_schedule_response("valid")

    assert {:ok, switch} = SwitchQueries.insert(ctx.switch_def)

    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(0), switch)

    target_2 = ctx.targets_defs |> Enum.at(1) |> Map.put("deployment_target", "non-existent")
    assert {:ok, _target} = TargetQueries.insert(target_2, switch)

    request = %{
      switch_id: switch.id,
      target_name: "prod",
      triggered_by: "user1",
      override: true,
      request_token: UUID.uuid4(),
      env_variables: []
    }

    assert {:ok, {:NOT_FOUND, message}} = Actions.trigger(request)

    assert String.starts_with?(
             message,
             "Triggering promotion with deployment target failed: deployment target not found"
           )
  end

  test "trigger() when target is bound to syncing deployment target then returns errors", ctx do
    Helpers.use_test_plumber_service(@grpc_port)
    Helpers.test_plumber_service_schedule_response("valid")

    assert {:ok, _dpl} = DeploymentQueries.create(ctx.dpl_def, ctx.encrypted_secret)
    assert {:ok, switch} = SwitchQueries.insert(ctx.switch_def)
    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(0), switch)

    target_2 = ctx.targets_defs |> Enum.at(1) |> Map.put("deployment_target", "production")
    assert {:ok, _target} = TargetQueries.insert(target_2, switch)

    request = %{
      switch_id: switch.id,
      target_name: "prod",
      triggered_by: "user1",
      override: true,
      request_token: UUID.uuid4(),
      env_variables: []
    }

    assert {:ok, {:REFUSED, message}} = Actions.trigger(request)

    assert String.starts_with?(
             message,
             "Triggering promotion with deployment target failed: deployment target is syncing"
           )
  end

  test "trigger() when target is bound to corrupted deployment target then returns errors", ctx do
    Helpers.use_test_plumber_service(@grpc_port)
    Helpers.test_plumber_service_schedule_response("valid")

    assert {:ok, dpl} = DeploymentQueries.create(ctx.dpl_def, ctx.encrypted_secret)
    assert {:ok, _dpl} = DeploymentQueries.fail_syncing(dpl, "network error")
    assert {:ok, switch} = SwitchQueries.insert(ctx.switch_def)
    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(0), switch)

    target_2 = ctx.targets_defs |> Enum.at(1) |> Map.put("deployment_target", "production")
    assert {:ok, _target} = TargetQueries.insert(target_2, switch)

    request = %{
      switch_id: switch.id,
      target_name: "prod",
      triggered_by: "user1",
      override: true,
      request_token: UUID.uuid4(),
      env_variables: []
    }

    assert {:ok, {:REFUSED, message}} = Actions.trigger(request)

    assert String.starts_with?(
             message,
             "Triggering promotion with deployment target failed: deployment target is corrupted"
           )
  end

  test "trigger() when target is bound to cordoned deployment target then returns errors", ctx do
    Helpers.use_test_plumber_service(@grpc_port)
    Helpers.test_plumber_service_schedule_response("valid")

    assert {:ok, dpl} = DeploymentQueries.create(ctx.dpl_def, :no_secret_params)
    assert {:ok, _dpl} = DeploymentQueries.cordon(dpl, true)
    assert {:ok, switch} = SwitchQueries.insert(ctx.switch_def)
    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(0), switch)

    target_2 = ctx.targets_defs |> Enum.at(1) |> Map.put("deployment_target", "production")
    assert {:ok, _target} = TargetQueries.insert(target_2, switch)

    request = %{
      switch_id: switch.id,
      target_name: "prod",
      triggered_by: "user1",
      override: true,
      request_token: UUID.uuid4(),
      env_variables: []
    }

    assert {:ok, {:REFUSED, message}} = Actions.trigger(request)

    assert String.starts_with?(
             message,
             "Triggering promotion with deployment target failed: deployment target is cordoned"
           )
  end

  test "trigger() when target is bound to deployment target then blocks wrong objects", ctx do
    Helpers.use_test_plumber_service(@grpc_port)
    Helpers.test_plumber_service_schedule_response("valid")

    assert {:ok, _dpl} = DeploymentQueries.create(ctx.dpl_def, :no_secret_params)

    assert {:ok, switch} =
             SwitchQueries.insert(%{ctx.switch_def | "git_ref_type" => "tag", "label" => "v1"})

    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(0), switch)

    target_2 = ctx.targets_defs |> Enum.at(1) |> Map.put("deployment_target", "production")
    assert {:ok, _target} = TargetQueries.insert(target_2, switch)

    request = %{
      switch_id: switch.id,
      target_name: "prod",
      triggered_by: "user1",
      override: true,
      request_token: UUID.uuid4(),
      env_variables: []
    }

    assert {:ok, {:REFUSED, message}} = Actions.trigger(request)

    assert String.starts_with?(
             message,
             "Triggering promotion with deployment target failed: object not allowed"
           )
  end

  test "trigger() when target is bound to deployment target then blocks wrong subjects", ctx do
    Helpers.use_test_plumber_service(@grpc_port)
    Helpers.test_plumber_service_schedule_response("valid")

    assert {:ok, _dpl} = DeploymentQueries.create(ctx.dpl_def, :no_secret_params)

    assert {:ok, switch} = SwitchQueries.insert(ctx.switch_def)
    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(0), switch)

    target_2 = ctx.targets_defs |> Enum.at(1) |> Map.put("deployment_target", "production")
    assert {:ok, _target} = TargetQueries.insert(target_2, switch)

    request = %{
      switch_id: switch.id,
      target_name: "prod",
      triggered_by: "user2",
      override: true,
      request_token: UUID.uuid4(),
      env_variables: []
    }

    assert {:ok, {:REFUSED, message}} = Actions.trigger(request)

    assert String.starts_with?(
             message,
             "Triggering promotion with deployment target failed: subject not allowed"
           )
  end

  test "trigger() when target is bound to deployment target then allows proper triggers", ctx do
    start_supervised!(
      {Test.MockDynamicSupervisor,
       [
         name: Gofer.DeploymentTrigger.Engine.Supervisor,
         call_extractor: &(&1 |> Map.get(:id))
       ]}
    )

    Helpers.use_test_plumber_service(@grpc_port)
    Helpers.test_plumber_service_schedule_response("valid")

    assert {:ok, %{id: _dpl_id}} = DeploymentQueries.create(ctx.dpl_def, :no_secret_params)

    assert {:ok, switch} = SwitchQueries.insert(ctx.switch_def)
    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(0), switch)

    target_2 = ctx.targets_defs |> Enum.at(1) |> Map.put("deployment_target", "production")
    assert {:ok, _target} = TargetQueries.insert(target_2, switch)

    request = %{
      switch_id: switch.id,
      target_name: "prod",
      triggered_by: "user1",
      override: true,
      request_token: UUID.uuid4(),
      env_variables: []
    }

    assert {:ok, {:OK, message}} = Actions.trigger(request)
    assert message == "Target trigger request recorded."

    assert [%DeploymentTrigger{id: trigger_id}] = Gofer.EctoRepo.all(DeploymentTrigger)

    assert {:ok, [{^trigger_id, _pid}]} =
             Test.MockDynamicSupervisor.get_calls(Gofer.DeploymentTrigger.Engine.Supervisor)
  end

  test "trigger() creates valid switch_trigger and starts switch_trigger_process when given valid params",
       ctx do
    Helpers.use_test_plumber_service(@grpc_port)
    Helpers.test_plumber_service_schedule_response("valid")

    assert {:ok, switch} = SwitchQueries.insert(ctx.switch_def)

    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(0), switch)
    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(1), switch)

    timestamp_before = DateTime.utc_now()

    request = %{
      switch_id: switch.id,
      target_name: "prod",
      triggered_by: "user1",
      override: true,
      request_token: UUID.uuid4(),
      env_variables: []
    }

    assert {:ok, {:OK, message}} = Actions.trigger(request)
    assert message == "Target trigger request recorded."

    assert {:ok, switch_trigger} =
             SwitchTriggerQueries.get_by_request_token(request.request_token)

    assert switch_trigger.switch_id == switch.id
    assert switch_trigger.request_token == request.request_token
    assert switch_trigger.target_names == ["prod"]
    assert switch_trigger.triggered_by == "user1"
    refute is_nil(switch_trigger.triggered_at)
    assert DateTime.compare(switch_trigger.triggered_at, timestamp_before) == :gt
    assert DateTime.compare(switch_trigger.triggered_at, DateTime.utc_now()) == :lt
    assert switch_trigger.auto_triggered == false
    assert switch_trigger.override == true
    assert switch_trigger.env_vars_for_target == %{"prod" => []}

    args = [SwitchTriggerQueries, :get_by_id, [switch_trigger.id]]
    Helpers.assert_finished_for_less_than(Helpers, :entity_processed?, args, 3_000)

    assert {:ok, target_trigger} =
             TargetTriggerQueries.get_by_id_and_name(switch_trigger.id, "prod")

    assert target_trigger.switch_id == switch.id
    assert {:ok, _} = target_trigger.schedule_request_token |> UUID.info()

    args = [TargetTriggerQueries, :get_by_id_and_name, [switch_trigger.id, "prod"]]
    Helpers.assert_finished_for_less_than(Helpers, :entity_processed?, args, 3_000)

    assert {:ok, target_trigger} =
             TargetTriggerQueries.get_by_id_and_name(switch_trigger.id, "prod")

    assert {:ok, _} = target_trigger.scheduled_ppl_id |> UUID.info()
    refute is_nil(target_trigger.scheduled_at)
    assert target_trigger.processing_result == "passed"
    assert DateTime.compare(switch_trigger.triggered_at, target_trigger.scheduled_at) == :lt
  end

  test "trigger() returns :REFUSED if ppl_result != passed and override = false", ctx do
    assert {:ok, switch} = SwitchQueries.insert(ctx.switch_def)

    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(0), switch)
    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(1), switch)

    request = %{
      switch_id: switch.id,
      target_name: "prod",
      triggered_by: "user1",
      override: false,
      request_token: UUID.uuid4(),
      env_variables: [%{name: "Test", value: "1"}]
    }

    assert {:ok, {:REFUSED, message}} = Actions.trigger(request)

    assert message ==
             "Triggering target when pipeline is not passed requires override confirmation."

    assert [] == SwitchTrigger |> where(switch_id: ^switch.id) |> Repo.all()
  end

  test "trigger() returns :REFUSED when pending queue limit is reached", ctx do
    previous_queue_limit = Application.get_env(:gofer, :target_trigger_queue_limit)
    Application.put_env(:gofer, :target_trigger_queue_limit, 1)

    on_exit(fn ->
      Application.put_env(:gofer, :target_trigger_queue_limit, previous_queue_limit)
    end)

    Helpers.use_test_plumber_service(@grpc_port)
    Helpers.test_plumber_service_schedule_response("timeout")

    assert {:ok, switch} = SwitchQueries.insert(ctx.switch_def)
    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(0), switch)
    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(1), switch)

    request_1 = %{
      switch_id: switch.id,
      target_name: "prod",
      triggered_by: "user1",
      override: true,
      request_token: UUID.uuid4(),
      env_variables: []
    }

    request_2 = %{
      switch_id: switch.id,
      target_name: "prod",
      triggered_by: "user1",
      override: true,
      request_token: UUID.uuid4(),
      env_variables: []
    }

    assert {:ok, {:OK, _message}} = Actions.trigger(request_1)

    assert :ok == wait_for_pending_count(switch.id, "prod", 1)

    assert {:ok, {:REFUSED, message}} = Actions.trigger(request_2)

    assert message ==
             "Too many pending promotions for target 'prod' (1/1). Please retry later."

    assert 1 == SwitchTrigger |> where(switch_id: ^switch.id) |> Repo.all() |> length()
  end

  test "trigger() is idempotent in regard to request_token", ctx do
    Helpers.use_test_plumber_service(@grpc_port)
    Helpers.test_plumber_service_schedule_response("valid")

    assert {:ok, switch} = SwitchQueries.insert(ctx.switch_def)

    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(0), switch)
    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(1), switch)

    request = %{
      switch_id: switch.id,
      target_name: "prod",
      triggered_by: "user1",
      override: true,
      request_token: UUID.uuid4(),
      env_variables: []
    }

    assert {:ok, {:OK, message}} = Actions.trigger(request)
    assert message == "Target trigger request recorded."

    assert {:ok, {:OK, message}} = Actions.trigger(request)
    assert message == "Target trigger request recorded."

    assert 1 == SwitchTrigger |> where(switch_id: ^switch.id) |> Repo.all() |> length()
  end

  defp wait_for_pending_count(switch_id, target_name, expected_count, attempts_left \\ 20) do
    case TargetTriggerQueries.get_unprocessed_triggers_count(switch_id, target_name) do
      {:ok, ^expected_count} ->
        :ok

      {:ok, _count} when attempts_left > 0 ->
        :timer.sleep(100)
        wait_for_pending_count(switch_id, target_name, expected_count, attempts_left - 1)

      {:ok, count} ->
        {:error, {:unexpected_count, count}}

      error ->
        error
    end
  end
end
