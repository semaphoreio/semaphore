defmodule Gofer.Actions.DescribeImpl.Test do
  use ExUnit.Case

  alias Gofer.Actions
  alias Gofer.Target.Model.TargetQueries
  alias Gofer.Switch.Model.SwitchQueries
  alias Gofer.Deployment.Model.DeploymentQueries
  alias Gofer.SwitchTrigger.Model.SwitchTriggerQueries
  alias Gofer.TargetTrigger.Model.TargetTriggerQueries
  alias Gofer.Switch.Engine.SwitchSupervisor, as: SSupervisor
  alias Gofer.SwitchTrigger.Engine.SwitchTriggerSupervisor, as: STSupervisor
  alias Gofer.TargetTrigger.Engine.TargetTriggerSupervisor, as: TTSupervisor
  alias Test.Helpers

  @grpc_port 50059

  setup_all do
    GRPC.Server.start(Test.MockPlumberService, @grpc_port)

    on_exit(fn ->
      GRPC.Server.stop(Test.MockPlumberService)
    end)

    {:ok, %{}}
  end

  setup do
    assert {:ok, _} = Ecto.Adapters.SQL.query(Gofer.EctoRepo, "truncate table switches cascade;")

    project_id = UUID.uuid4()
    user_id = UUID.uuid4()

    switch_def = %{
      "id" => UUID.uuid4(),
      "ppl_id" => UUID.uuid4(),
      "project_id" => project_id,
      "git_ref_type" => "branch",
      "label" => "master",
      "prev_ppl_artefact_ids" => [],
      "branch_name" => "master"
    }

    target_1 = %{
      "name" => "staging",
      "pipeline_path" => "./stg.yml",
      "predefined_env_vars" => %{},
      "auto_trigger_on" => [%{"result" => "passed", "branch" => ["mast.", "xyz"]}]
    }

    target_2 = %{
      "name" => "prod",
      "pipeline_path" => "./prod.yml",
      "deployment_target" => "production",
      "predefined_env_vars" => %{}
    }

    targets_defs = [target_1, target_2]

    dpl_def = %{
      "name" => "production",
      "organization_id" => UUID.uuid4(),
      "project_id" => project_id,
      "unique_token" => UUID.uuid4(),
      "created_by" => UUID.uuid4(),
      "updated_by" => UUID.uuid4(),
      "subject_rules" => [%{"type" => "USER", "subject_id" => user_id}],
      "object_rules" => [%{"type" => "BRANCH", "match_mode" => "EXACT", "pattern" => "master"}]
    }

    start_supervised!(SSupervisor)
    start_supervised!(STSupervisor)
    start_supervised!(TTSupervisor)

    {:ok,
     %{
       project_id: project_id,
       user_id: user_id,
       dpl_def: dpl_def,
       switch_def: switch_def,
       targets_defs: targets_defs
     }}
  end

  # Describe

  test "describe returns valid result when given valid params", ctx do
    Helpers.use_test_plumber_service(@grpc_port)
    Helpers.test_plumber_service_schedule_response("valid")

    assert {:ok, dpl} = DeploymentQueries.create(ctx.dpl_def, :no_secret_params)
    assert {:ok, switch} = SwitchQueries.insert(ctx.switch_def)

    pev_1 = %{
      "name" => "TEST",
      "options" => ["1", "2"],
      "default_value" => "3",
      "required" => false,
      "description" => ""
    }

    pev_2 = %{
      "name" => "ENV_VAR",
      "options" => [],
      "default_value" => "",
      "required" => true,
      "description" => "asdf"
    }

    target_1 =
      ctx.targets_defs
      |> Enum.at(0)
      |> Map.put("parameter_env_vars", %{"TEST" => pev_1, "ENV_VAR" => pev_2})

    assert {:ok, _target} = TargetQueries.insert(target_1, switch)
    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(1), switch)

    SwitchQueries.update(switch, %{"ppl_done" => true, "ppl_result" => "passed"})

    trigger_targets(switch.id, "1")

    assert {:ok, result} = Actions.describe_switch(switch.id, 5, ctx.user_id)
    assert result.pipeline_done == true
    assert result.pipeline_result == "passed"
    assert result.ppl_id == switch.ppl_id
    assert result.switch_id == switch.id
    assert targets_description_valid(result.targets, true, 5, dpl.id, ["1"])
  end

  defp targets_description_valid(targets, has_triggers?, triggers_no, dpl_id, names \\ [])

  defp targets_description_valid(targets, has_triggers?, triggers_no, dpl_id, names)
       when is_list(targets) do
    targets
    |> Enum.map(fn target ->
      assert target.name in ["prod", "staging"]
      assert target.pipeline_path in ["./prod.yml", "./stg.yml"]

      cond do
        target.name == "staging" ->
          assert target.auto_trigger_on == [%{"result" => "passed", "branch" => ["mast.", "xyz"]}]

          p_e_v_1 = %{
            name: "TEST",
            options: ["1", "2"],
            default_value: "3",
            required: false,
            description: ""
          }

          p_e_v_2 = %{
            name: "ENV_VAR",
            options: [],
            default_value: "",
            required: true,
            description: "asdf"
          }

          assert target.parameter_env_vars |> Enum.member?(p_e_v_1)
          assert target.parameter_env_vars |> Enum.member?(p_e_v_2)
          assert is_nil(target[:dt_description])

        target.name == "prod" ->
          assert target.auto_trigger_on == []
          assert target.parameter_env_vars == []
          refute is_nil(target[:dt_description])
          assert target.dt_description.target_id == dpl_id
          assert target.dt_description.target_name == "production"
          assert target.dt_description.access.allowed == true
          assert target.dt_description.access.reason == :NO_REASON
          assert target.dt_description.access.message == "You can deploy to %{deployment_target}"
      end

      case has_triggers? do
        true -> assert trigger_events_correct(target.trigger_events, triggers_no, names)
        false -> assert target.trigger_events == []
      end
    end)

    true
  end

  defp targets_description_valid(_, _, _, _, _), do: false

  defp trigger_events_correct(triggers, triggers_no, names) when is_list(triggers) do
    assert length(triggers) <= triggers_no

    triggers
    |> Enum.with_index()
    |> Enum.map(fn {trigger, ind} ->
      assert trigger.auto_triggered == false
      assert trigger.error_response == ""
      assert trigger.override == false
      assert trigger.processed == true
      assert trigger.processing_result == "passed"
      assert DateTime.compare(trigger.triggered_at, DateTime.utc_now()) == :lt
      assert DateTime.compare(trigger.scheduled_at, DateTime.utc_now()) == :lt
      assert DateTime.compare(trigger.triggered_at, trigger.scheduled_at) == :lt
      assert {:ok, _} = UUID.info(trigger.scheduled_pipeline_id)
      assert trigger.target_name in ["prod", "staging"]

      if trigger.target_name == "staging" do
        assert trigger.env_variables ==
                 [
                   %{"name" => "TEST", "value" => "1"},
                   %{"name" => "NOT_PREDEFINED", "value" => "something"}
                 ]
      end

      assert trigger.triggered_by == "Pipeline Done request" <> Enum.at(names, ind)
    end)

    true
  end

  defp trigger_events_correct(_, _, _), do: false

  test "describe returns expected when there are no target_trigger_events", ctx do
    assert {:ok, switch} = SwitchQueries.insert(ctx.switch_def)
    assert {:ok, dpl} = DeploymentQueries.create(ctx.dpl_def, :no_secret_params)

    pev_1 = %{
      "name" => "TEST",
      "options" => ["1", "2"],
      "default_value" => "3",
      "required" => false,
      "description" => ""
    }

    pev_2 = %{
      "name" => "ENV_VAR",
      "options" => [],
      "default_value" => "",
      "required" => true,
      "description" => "asdf"
    }

    target_1 =
      ctx.targets_defs
      |> Enum.at(0)
      |> Map.put("parameter_env_vars", %{"TEST" => pev_1, "ENV_VAR" => pev_2})

    assert {:ok, _target} = TargetQueries.insert(target_1, switch)
    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(1), switch)

    assert {:ok, result} = Actions.describe_switch(switch.id, 5, ctx.user_id)
    assert result.pipeline_done == false
    assert result.pipeline_result == ""
    assert result.ppl_id == switch.ppl_id
    assert result.switch_id == switch.id
    assert targets_description_valid(result.targets, false, 5, dpl.id)
  end

  test "describe returns NOT_FOUND error when switch is not found", ctx do
    id = UUID.uuid4()
    assert {:ok, {:NOT_FOUND, message}} = Actions.describe_switch(id, 5, ctx.user_id)
    assert message == "Switch with id #{id} not found."
  end

  test "describe returns requested number of target_trigger_events when there are more than requested",
       ctx do
    Helpers.use_test_plumber_service(@grpc_port)
    Helpers.test_plumber_service_schedule_response("valid")

    assert {:ok, switch} = SwitchQueries.insert(ctx.switch_def)
    assert {:ok, dpl} = DeploymentQueries.create(ctx.dpl_def, :no_secret_params)

    pev_1 = %{
      "name" => "TEST",
      "options" => ["1", "2"],
      "default_value" => "3",
      "required" => false,
      "description" => ""
    }

    pev_2 = %{
      "name" => "ENV_VAR",
      "options" => [],
      "default_value" => "",
      "required" => true,
      "description" => "asdf"
    }

    target_1 =
      ctx.targets_defs
      |> Enum.at(0)
      |> Map.put("parameter_env_vars", %{"TEST" => pev_1, "ENV_VAR" => pev_2})

    assert {:ok, _target} = TargetQueries.insert(target_1, switch)
    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(1), switch)

    SwitchQueries.update(switch, %{"ppl_done" => true, "ppl_result" => "passed"})

    "12345"
    |> String.codepoints()
    |> Enum.map(fn ind -> trigger_targets(switch.id, ind) end)

    assert {:ok, result} = Actions.describe_switch(switch.id, 3, ctx.user_id)
    assert result.pipeline_done == true
    assert result.pipeline_result == "passed"
    assert result.ppl_id == switch.ppl_id
    assert result.switch_id == switch.id
    assert targets_description_valid(result.targets, true, 3, dpl.id, ["5", "4", "3"])
  end

  test "when deployment target is missing then omits the given target", ctx do
    assert {:ok, switch} = SwitchQueries.insert(ctx.switch_def)
    assert {:ok, dpl} = DeploymentQueries.create(ctx.dpl_def, :no_secret_params)

    pev_1 = %{
      "name" => "TEST",
      "options" => ["1", "2"],
      "default_value" => "3",
      "required" => false,
      "description" => ""
    }

    pev_2 = %{
      "name" => "ENV_VAR",
      "options" => [],
      "default_value" => "",
      "required" => true,
      "description" => "asdf"
    }

    target_1 =
      ctx.targets_defs
      |> Enum.at(0)
      |> Map.put("parameter_env_vars", %{"TEST" => pev_1, "ENV_VAR" => pev_2})
      |> Map.put("deployment_target", "non-existent")

    assert {:ok, _target} = TargetQueries.insert(target_1, switch)
    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(1), switch)

    assert {:ok, result} = Actions.describe_switch(switch.id, 5, "")
    assert result.pipeline_done == false
    assert result.pipeline_result == ""
    assert result.ppl_id == switch.ppl_id
    assert result.switch_id == switch.id

    assert Enum.count(result.targets) == 2

    assert target = Enum.find(result.targets, &(&1.name == "staging"))
    refute is_nil(target[:dt_description])
    assert target.dt_description.target_id == ""
    assert target.dt_description.target_name == "non-existent"
    assert target.dt_description.access.allowed == false
    assert target.dt_description.access.reason == :CORRUPTED_TARGET

    assert target.dt_description.access.message ==
             "%{deployment_target} was deleted, promotions are blocked for security reasons"

    assert target = Enum.find(result.targets, &(&1.name == "prod"))
    refute is_nil(target[:dt_description])
    assert target.dt_description.target_id == dpl.id
    assert target.dt_description.target_name == "production"
    assert target.dt_description.access.allowed == false
    assert target.dt_description.access.reason == :BANNED_SUBJECT

    assert target.dt_description.access.message ==
             "You don't have rights to deploy to %{deployment_target}"
  end

  test "when requester_id is empty then promos with DTs are denied", ctx do
    assert {:ok, switch} = SwitchQueries.insert(ctx.switch_def)
    assert {:ok, dpl} = DeploymentQueries.create(ctx.dpl_def, :no_secret_params)

    pev_1 = %{
      "name" => "TEST",
      "options" => ["1", "2"],
      "default_value" => "3",
      "required" => false,
      "description" => ""
    }

    pev_2 = %{
      "name" => "ENV_VAR",
      "options" => [],
      "default_value" => "",
      "required" => true,
      "description" => "asdf"
    }

    target_1 =
      ctx.targets_defs
      |> Enum.at(0)
      |> Map.put("parameter_env_vars", %{"TEST" => pev_1, "ENV_VAR" => pev_2})

    assert {:ok, _target} = TargetQueries.insert(target_1, switch)
    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(1), switch)

    assert {:ok, result} = Actions.describe_switch(switch.id, 5, "")
    assert result.pipeline_done == false
    assert result.pipeline_result == ""
    assert result.ppl_id == switch.ppl_id
    assert result.switch_id == switch.id

    assert target = Enum.find(result.targets, &(&1.name == "staging"))
    assert is_nil(target[:dt_description])

    assert target = Enum.find(result.targets, &(&1.name == "prod"))
    refute is_nil(target[:dt_description])
    assert target.dt_description.target_id == dpl.id
    assert target.dt_description.target_name == "production"
    assert target.dt_description.access.allowed == false
    assert target.dt_description.access.reason == :BANNED_SUBJECT

    assert target.dt_description.access.message ==
             "You don't have rights to deploy to %{deployment_target}"
  end

  test "when requester_id is banned from promotions then promos with DTs are denied", ctx do
    assert {:ok, switch} = SwitchQueries.insert(ctx.switch_def)
    assert {:ok, dpl} = DeploymentQueries.create(ctx.dpl_def, :no_secret_params)

    pev_1 = %{
      "name" => "TEST",
      "options" => ["1", "2"],
      "default_value" => "3",
      "required" => false,
      "description" => ""
    }

    pev_2 = %{
      "name" => "ENV_VAR",
      "options" => [],
      "default_value" => "",
      "required" => true,
      "description" => "asdf"
    }

    target_1 =
      ctx.targets_defs
      |> Enum.at(0)
      |> Map.put("parameter_env_vars", %{"TEST" => pev_1, "ENV_VAR" => pev_2})

    assert {:ok, _target} = TargetQueries.insert(target_1, switch)
    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(1), switch)

    assert {:ok, result} = Actions.describe_switch(switch.id, 5, UUID.uuid4())
    assert result.pipeline_done == false
    assert result.pipeline_result == ""
    assert result.ppl_id == switch.ppl_id
    assert result.switch_id == switch.id

    assert target = Enum.find(result.targets, &(&1.name == "staging"))
    assert is_nil(target[:dt_description])

    assert target = Enum.find(result.targets, &(&1.name == "prod"))
    refute is_nil(target[:dt_description])
    assert target.dt_description.target_id == dpl.id
    assert target.dt_description.target_name == "production"
    assert target.dt_description.access.allowed == false
    assert target.dt_description.access.reason == :BANNED_SUBJECT

    assert target.dt_description.access.message ==
             "You don't have rights to deploy to %{deployment_target}"
  end

  test "when git target is banned from promotions then promos with DTs are denied", ctx do
    switch_def = %{ctx.switch_def | "git_ref_type" => "branch", "label" => "develop"}

    assert {:ok, switch} = SwitchQueries.insert(switch_def)
    assert {:ok, dpl} = DeploymentQueries.create(ctx.dpl_def, :no_secret_params)

    pev_1 = %{
      "name" => "TEST",
      "options" => ["1", "2"],
      "default_value" => "3",
      "required" => false,
      "description" => ""
    }

    pev_2 = %{
      "name" => "ENV_VAR",
      "options" => [],
      "default_value" => "",
      "required" => true,
      "description" => "asdf"
    }

    target_1 =
      ctx.targets_defs
      |> Enum.at(0)
      |> Map.put("parameter_env_vars", %{"TEST" => pev_1, "ENV_VAR" => pev_2})

    assert {:ok, _target} = TargetQueries.insert(target_1, switch)
    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(1), switch)

    assert {:ok, result} = Actions.describe_switch(switch.id, 5, UUID.uuid4())
    assert result.pipeline_done == false
    assert result.pipeline_result == ""
    assert result.ppl_id == switch.ppl_id
    assert result.switch_id == switch.id

    assert target = Enum.find(result.targets, &(&1.name == "staging"))
    assert is_nil(target[:dt_description])

    assert target = Enum.find(result.targets, &(&1.name == "prod"))
    refute is_nil(target[:dt_description])
    assert target.dt_description.target_id == dpl.id
    assert target.dt_description.target_name == "production"
    assert target.dt_description.access.allowed == false
    assert target.dt_description.access.reason == :BANNED_OBJECT

    assert target.dt_description.access.message ==
             ~s(Deployments from branch "develop" to %{deployment_target} are forbidden)
  end

  test "when target is syncing then promos with DTs are denied", ctx do
    switch_def = %{ctx.switch_def | "git_ref_type" => "branch", "label" => "develop"}

    assert {:ok, switch} = SwitchQueries.insert(switch_def)

    assert {:ok, dpl} =
             DeploymentQueries.create(ctx.dpl_def, %{
               requester_id: UUID.uuid4(),
               unique_token: UUID.uuid4(),
               key_id: DateTime.utc_now() |> DateTime.to_unix() |> to_string(),
               aes256_key: "asdfghjkl",
               init_vector: "asdfghjkl",
               payload: "qwertyuiopasdfghjklzxcvbnm"
             })

    pev_1 = %{
      "name" => "TEST",
      "options" => ["1", "2"],
      "default_value" => "3",
      "required" => false,
      "description" => ""
    }

    pev_2 = %{
      "name" => "ENV_VAR",
      "options" => [],
      "default_value" => "",
      "required" => true,
      "description" => "asdf"
    }

    target_1 =
      ctx.targets_defs
      |> Enum.at(0)
      |> Map.put("parameter_env_vars", %{"TEST" => pev_1, "ENV_VAR" => pev_2})

    assert {:ok, _target} = TargetQueries.insert(target_1, switch)
    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(1), switch)

    assert {:ok, result} = Actions.describe_switch(switch.id, 5, UUID.uuid4())
    assert result.pipeline_done == false
    assert result.pipeline_result == ""
    assert result.ppl_id == switch.ppl_id
    assert result.switch_id == switch.id

    assert target = Enum.find(result.targets, &(&1.name == "staging"))
    assert is_nil(target[:dt_description])

    assert target = Enum.find(result.targets, &(&1.name == "prod"))
    refute is_nil(target[:dt_description])
    assert target.dt_description.target_id == dpl.id
    assert target.dt_description.target_name == "production"
    assert target.dt_description.access.allowed == false
    assert target.dt_description.access.reason == :SYNCING_TARGET

    assert target.dt_description.access.message ==
             ~s(%{deployment_target} is syncing, please wait)
  end

  test "when target is corrupted then promos with DTs are denied", ctx do
    switch_def = %{ctx.switch_def | "git_ref_type" => "branch", "label" => "develop"}

    assert {:ok, switch} = SwitchQueries.insert(switch_def)

    assert {:ok, dpl} =
             DeploymentQueries.create(ctx.dpl_def, %{
               requester_id: UUID.uuid4(),
               unique_token: UUID.uuid4(),
               key_id: DateTime.utc_now() |> DateTime.to_unix() |> to_string(),
               aes256_key: "asdfghjkl",
               init_vector: "asdfghjkl",
               payload: "qwertyuiopasdfghjklzxcvbnm"
             })

    assert {:ok, dpl} = DeploymentQueries.fail_syncing(dpl, "network error")

    pev_1 = %{
      "name" => "TEST",
      "options" => ["1", "2"],
      "default_value" => "3",
      "required" => false,
      "description" => ""
    }

    pev_2 = %{
      "name" => "ENV_VAR",
      "options" => [],
      "default_value" => "",
      "required" => true,
      "description" => "asdf"
    }

    target_1 =
      ctx.targets_defs
      |> Enum.at(0)
      |> Map.put("parameter_env_vars", %{"TEST" => pev_1, "ENV_VAR" => pev_2})

    assert {:ok, _target} = TargetQueries.insert(target_1, switch)
    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(1), switch)

    assert {:ok, result} = Actions.describe_switch(switch.id, 5, UUID.uuid4())
    assert result.pipeline_done == false
    assert result.pipeline_result == ""
    assert result.ppl_id == switch.ppl_id
    assert result.switch_id == switch.id

    assert target = Enum.find(result.targets, &(&1.name == "staging"))
    assert is_nil(target[:dt_description])

    assert target = Enum.find(result.targets, &(&1.name == "prod"))
    refute is_nil(target[:dt_description])
    assert target.dt_description.target_id == dpl.id
    assert target.dt_description.target_name == "production"
    assert target.dt_description.access.allowed == false
    assert target.dt_description.access.reason == :CORRUPTED_TARGET

    assert target.dt_description.access.message ==
             ~s(%{deployment_target} is corrupted and cannot be used to promote)
  end

  test "when target is cordoned then promos with DTs are denied", ctx do
    switch_def = %{ctx.switch_def | "git_ref_type" => "branch", "label" => "develop"}

    assert {:ok, switch} = SwitchQueries.insert(switch_def)
    assert {:ok, dpl} = DeploymentQueries.create(ctx.dpl_def, :no_secret_params)
    assert {:ok, dpl} = DeploymentQueries.cordon(dpl, true)

    pev_1 = %{
      "name" => "TEST",
      "options" => ["1", "2"],
      "default_value" => "3",
      "required" => false,
      "description" => ""
    }

    pev_2 = %{
      "name" => "ENV_VAR",
      "options" => [],
      "default_value" => "",
      "required" => true,
      "description" => "asdf"
    }

    target_1 =
      ctx.targets_defs
      |> Enum.at(0)
      |> Map.put("parameter_env_vars", %{"TEST" => pev_1, "ENV_VAR" => pev_2})

    assert {:ok, _target} = TargetQueries.insert(target_1, switch)
    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(1), switch)

    assert {:ok, result} = Actions.describe_switch(switch.id, 5, UUID.uuid4())
    assert result.pipeline_done == false
    assert result.pipeline_result == ""
    assert result.ppl_id == switch.ppl_id
    assert result.switch_id == switch.id

    assert target = Enum.find(result.targets, &(&1.name == "staging"))
    assert is_nil(target[:dt_description])

    assert target = Enum.find(result.targets, &(&1.name == "prod"))
    refute is_nil(target[:dt_description])
    assert target.dt_description.target_id == dpl.id
    assert target.dt_description.target_name == "production"
    assert target.dt_description.access.allowed == false
    assert target.dt_description.access.reason == :CORDONED_TARGET

    assert target.dt_description.access.message ==
             ~s(%{deployment_target} is cordoned and cannot be used to promote)
  end

  defp trigger_targets(switch_id, ind) do
    params = form_switch_trigger_params(switch_id, ind, ["prod", "staging"])
    id = params |> Map.get("id")

    STSupervisor.start_switch_trigger_process(id, params)

    # STP processed

    args = [SwitchTriggerQueries, :get_by_id, [id]]
    Helpers.assert_finished_for_less_than(Helpers, :entity_processed?, args, 3_000)

    # Both TTPs processed

    args = [TargetTriggerQueries, :get_by_id_and_name, [id, "staging"]]
    Helpers.assert_finished_for_less_than(Helpers, :entity_processed?, args, 3_000)

    args = [TargetTriggerQueries, :get_by_id_and_name, [id, "prod"]]
    Helpers.assert_finished_for_less_than(Helpers, :entity_processed?, args, 3_000)
  end

  defp form_switch_trigger_params(switch_id, request_token, target_names) do
    %{
      "id" => UUID.uuid4(),
      "switch_id" => switch_id,
      "request_token" => request_token,
      "target_names" => target_names,
      "triggered_by" => "Pipeline Done request" <> request_token,
      "triggered_at" => DateTime.utc_now(),
      "auto_triggered" => false,
      "override" => false,
      "processed" => false,
      "env_vars_for_target" => %{
        "staging" => [%{name: "TEST", value: "1"}, %{name: "NOT_PREDEFINED", value: "something"}]
      }
    }
  end
end
