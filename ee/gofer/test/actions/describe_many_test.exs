defmodule Gofer.Actions.DescribeManyImpl.Test do
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

  @grpc_port 50063

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
      "predefined_env_vars" => %{},
      "deployment_target" => "production"
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

    {:ok, dpl} = DeploymentQueries.create(dpl_def, :no_secret_params)
    {:ok, _dpl} = DeploymentQueries.pass_syncing(dpl, %{secret_id: "foo", secret_name: "bar"})

    start_supervised!(SSupervisor)
    start_supervised!(STSupervisor)
    start_supervised!(TTSupervisor)

    {:ok,
     %{
       project_id: project_id,
       user_id: user_id,
       switch_def: switch_def,
       targets_defs: targets_defs
     }}
  end

  test "describe_many returns error if more switches was requested than supported max no", ctx do
    ids = 1..15 |> Enum.map(fn _ -> UUID.uuid4() end)
    assert {:error, message} = Actions.describe_many(ids, 5, ctx.user_id)
    assert message == "Requested 15 switches which is more than limit of 10."
  end

  test "describe_many returns NOT_FOUND if one of ids is not valid", ctx do
    Helpers.use_test_plumber_service(@grpc_port)
    Helpers.test_plumber_service_schedule_response("valid")

    assert {:ok, switch_1} = insert_and_trigger_switch(ctx, "1")

    assert {:error, {:NOT_FOUND, msg}} =
             Actions.describe_many([switch_1.id, "wrong-id"], 5, ctx.user_id)

    assert msg == "Switch with id: 'wrong-id' not found."
  end

  test "given valid params describe_many returns valid result", ctx do
    Helpers.use_test_plumber_service(@grpc_port)
    Helpers.test_plumber_service_schedule_response("valid")

    assert {:ok, switch_1} = insert_and_trigger_switch(ctx, "1")
    assert {:ok, switch_2} = insert_and_trigger_switch(ctx, "2")

    assert {:ok, switch_1_desc} = Actions.describe_switch(switch_1.id, 5, ctx.user_id)
    assert {:ok, switch_2_desc} = Actions.describe_switch(switch_2.id, 5, ctx.user_id)

    assert {:ok, [switch_1_desc, switch_2_desc]} ==
             Actions.describe_many([switch_1.id, switch_2.id], 5, ctx.user_id)
  end

  test "given valid params and empty requester_id describe_many returns valid result", ctx do
    Helpers.use_test_plumber_service(@grpc_port)
    Helpers.test_plumber_service_schedule_response("valid")

    assert {:ok, switch_1} = insert_and_trigger_switch(ctx, "1")
    assert {:ok, switch_2} = insert_and_trigger_switch(ctx, "2")

    assert {:ok, switch_1_desc} = Actions.describe_switch(switch_1.id, 5, "")
    assert {:ok, switch_2_desc} = Actions.describe_switch(switch_2.id, 5, "")

    assert {:ok, [switch_1_desc, switch_2_desc]} ==
             Actions.describe_many([switch_1.id, switch_2.id], 5, "")
  end

  defp insert_and_trigger_switch(ctx, ind) do
    assert {:ok, switch} =
             ctx.switch_def
             |> Map.merge(%{"id" => UUID.uuid4(), "ppl_id" => UUID.uuid4()})
             |> SwitchQueries.insert()

    env_vars = %{"TEST" => ["1", "2"], "ENV_VAR" => ["some", "value"]}
    target_1 = ctx.targets_defs |> Enum.at(0) |> Map.put("predefined_env_vars", env_vars)

    assert {:ok, _target} = TargetQueries.insert(target_1, switch)
    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(1), switch)

    SwitchQueries.update(switch, %{"ppl_done" => true, "ppl_result" => "passed"})

    trigger_targets(switch.id, ind)
    {:ok, switch}
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
