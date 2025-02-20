defmodule Gofer.Actions.CreateImpl.Test do
  use ExUnit.Case

  alias Gofer.Actions
  alias Gofer.Target.Model.TargetQueries
  alias Gofer.Switch.Model.SwitchQueries
  alias Gofer.Deployment.Model.DeploymentQueries
  alias Gofer.Switch.Engine.SwitchSupervisor, as: SSupervisor
  alias Gofer.SwitchTrigger.Engine.SwitchTriggerSupervisor, as: STSupervisor
  alias Gofer.TargetTrigger.Engine.TargetTriggerSupervisor, as: TTSupervisor

  @grpc_port 50053

  setup_all do
    GRPC.Server.start(Test.MockPlumberService, @grpc_port)

    on_exit(fn ->
      GRPC.Server.stop(Test.MockPlumberService)
    end)

    {:ok, %{}}
  end

  setup do
    assert {:ok, _} = Ecto.Adapters.SQL.query(Gofer.EctoRepo, "truncate table switches cascade;")

    assert {:ok, dpl} =
             DeploymentQueries.create(
               %{
                 name: "production",
                 organization_id: UUID.uuid4(),
                 project_id: UUID.uuid4(),
                 unique_token: UUID.uuid4(),
                 created_by: UUID.uuid4(),
                 updated_by: UUID.uuid4()
               },
               :no_secret_params
             )

    switch_def = %{
      "id" => UUID.uuid4(),
      "ppl_id" => UUID.uuid4(),
      "project_id" => dpl.project_id,
      "prev_ppl_artefact_ids" => [],
      "branch_name" => "master"
    }

    target_1 = %{
      "name" => "staging",
      "pipeline_path" => "./stg.yml",
      "predefined_env_vars" => %{},
      "auto_trigger_on" => [%{"result" => "passed", "branch" => ["mast.", "xyz"]}],
      "deployment_target" => ""
    }

    target_2 = %{
      "name" => "prod",
      "pipeline_path" => "./prod.yml",
      "predefined_env_vars" => %{},
      "deployment_target" => "production"
    }

    targets_defs = [target_1, target_2]

    start_supervised!(SSupervisor)
    start_supervised!(STSupervisor)
    start_supervised!(TTSupervisor)

    {:ok, %{project_id: dpl.project_id, switch_def: switch_def, targets_defs: targets_defs}}
  end

  test "persists switch and targets when given valid params and starts switch process", ctx do
    assert {:ok, switch_id} = Actions.create_switch(ctx.switch_def, ctx.targets_defs)
    assert {:ok, switch} = SwitchQueries.get_by_id(switch_id)
    assert switch.ppl_id == Map.get(ctx.switch_def, "ppl_id")

    assert {:ok, target_1} = TargetQueries.get_by_id_and_name(switch.id, "staging")
    assert "./stg.yml" == target_1.pipeline_path
    assert target_1.auto_trigger_on == [%{"result" => "passed", "branch" => ["mast.", "xyz"]}]
    assert is_nil(target_1.deployment_target)

    assert {:ok, target_2} = TargetQueries.get_by_id_and_name(switch.id, "prod")
    assert "./prod.yml" == target_2.pipeline_path
    assert target_2.auto_trigger_on == []
    assert target_2.deployment_target == "production"

    assert {:error, {:already_started, _}} =
             SSupervisor.start_switch_process(switch.id, {ctx.switch_def, ctx.targets_defs})
  end

  test "create_switch is idempotent in regard to ppl_id", ctx do
    assert {:ok, switch_1_id} = Actions.create_switch(ctx.switch_def, ctx.targets_defs)

    assert %{active: 1} = SSupervisor.count_children()

    assert {:ok, switch_1} = SwitchQueries.get_by_id(switch_1_id)
    assert switch_1.ppl_id == Map.get(ctx.switch_def, "ppl_id")

    assert {:ok, switch_2_id} = Actions.create_switch(ctx.switch_def, ctx.targets_defs)
    assert switch_2_id == switch_1_id
    assert %{active: 1} = SSupervisor.count_children()
  end

  test "error when ppl_id for switch is empty", ctx do
    switch_def = ctx.switch_def |> Map.delete("ppl_id")
    assert {:error, message} = Actions.create_switch(switch_def, ctx.targets_defs)
    assert %{ppl_id: {"can't be blank", [validation: :required]}} == message
    assert %{active: 0} = SSupervisor.count_children()
  end

  test "error when two targets have same name", ctx do
    targets = ctx.targets_defs ++ [%{"name" => "prod", "pipeline_path" => "./prod.yml"}]
    assert {:error, {:MALFORMED, message}} = Actions.create_switch(ctx.switch_def, targets)
    assert "There are at least two targets with same name: prod" = message
    assert %{active: 0} = SSupervisor.count_children()
  end

  test "error when two param env vars have same name", ctx do
    pev = %{
      "name" => "ENV_VAR",
      "options" => [],
      "default_value" => "",
      "required" => true,
      "description" => "asdf"
    }

    malformed_target = %{
      "name" => "failing",
      "pipeline_path" => "./prod.yml",
      "parameter_env_vars" => [pev, pev]
    }

    targets = ctx.targets_defs ++ [malformed_target]
    assert {:error, {:MALFORMED, message}} = Actions.create_switch(ctx.switch_def, targets)

    assert message ==
             "Parameter environment variable with name 'ENV_VAR' is defined at least two times."

    assert %{active: 0} = SSupervisor.count_children()
  end

  test "error when there is an optional env var with defined default_value", ctx do
    pev = %{
      "name" => "ENV_VAR",
      "options" => [],
      "default_value" => "5",
      "required" => false,
      "description" => "asdf"
    }

    malformed_target = %{
      "name" => "failing",
      "pipeline_path" => "./prod.yml",
      "parameter_env_vars" => [pev]
    }

    targets = ctx.targets_defs ++ [malformed_target]
    assert {:error, {:MALFORMED, message}} = Actions.create_switch(ctx.switch_def, targets)

    assert message ==
             "Invalid parameter: 'ENV_VAR' - it can either be optional or have default value."

    assert %{active: 0} = SSupervisor.count_children()
  end

  test "error when deployment target doesn't exist", ctx do
    malformed_target = %{
      "name" => "failing",
      "pipeline_path" => "./prod.yml",
      "deployment_target" => "non-existent"
    }

    targets = ctx.targets_defs ++ [malformed_target]

    assert {:error, {:MALFORMED, message}} = Actions.create_switch(ctx.switch_def, targets)
    assert message == ~s(Invalid parameter: 'non-existent' deployment target not found)

    assert %{active: 0} = SSupervisor.count_children()
  end
end
