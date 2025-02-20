defmodule Gofer.Switch.Engine.DbScanner.Test do
  use ExUnit.Case

  alias Gofer.Switch.Engine.SwitchSupervisor, as: SSupervisor
  alias Gofer.SwitchTrigger.Engine.SwitchTriggerSupervisor, as: STSupervisor
  alias Gofer.TargetTrigger.Engine.TargetTriggerSupervisor, as: TTSupervisor
  alias Gofer.Switch.Engine.DbScanner
  alias Gofer.Switch.Model.SwitchQueries
  alias Gofer.Target.Model.TargetQueries
  alias Gofer.Deployment.Model.DeploymentQueries

  setup do
    assert {:ok, _} =
             Ecto.Adapters.SQL.query(Gofer.EctoRepo, "truncate table deployments cascade;")

    assert {:ok, _} = Ecto.Adapters.SQL.query(Gofer.EctoRepo, "truncate table switches cascade;")
    start_supervised!(SSupervisor)
    start_supervised!(STSupervisor)
    start_supervised!(TTSupervisor)

    assert {:ok, _} =
             DeploymentQueries.create(
               %{
                 name: "production",
                 organization_id: UUID.uuid4(),
                 project_id: "project1",
                 unique_token: UUID.uuid4(),
                 created_by: UUID.uuid4(),
                 updated_by: UUID.uuid4()
               },
               :no_secret_params
             )

    sw_1_def = %{
      "id" => UUID.uuid4(),
      "ppl_id" => UUID.uuid4(),
      "project_id" => "project1",
      "prev_ppl_artefact_ids" => [],
      "branch_name" => "master"
    }

    assert {:ok, switch_1} = SwitchQueries.insert(sw_1_def)

    request = %{
      "name" => "stg",
      "pipeline_path" => "./stg.yml",
      "auto" => true,
      "predefined_env_vars" => %{},
      "deployment_target" => ""
    }

    assert {:ok, _target_1} = TargetQueries.insert(request, switch_1)
    tg1_def = request |> Map.put("switch_id", switch_1.id)

    request = %{
      "name" => "prod",
      "pipeline_path" => "./prod.yml",
      "predefined_env_vars" => %{},
      "deployment_target" => "production"
    }

    assert {:ok, _target_2} = TargetQueries.insert(request, switch_1)
    tg2_def = request |> Map.put("switch_id", switch_1.id)

    tg_defs_1 = [tg1_def, tg2_def]
    params_1 = {sw_1_def, tg_defs_1}

    sw_2_def = %{
      "id" => UUID.uuid4(),
      "ppl_id" => UUID.uuid4(),
      "project_id" => "project1",
      "prev_ppl_artefact_ids" => [],
      "branch_name" => "master"
    }

    assert {:ok, switch_2} = SwitchQueries.insert(sw_2_def)

    request = %{
      "name" => "stg",
      "pipeline_path" => "./stg.yml",
      "auto" => true,
      "predefined_env_vars" => %{}
    }

    assert {:ok, _target_1} = TargetQueries.insert(request, switch_2)
    tg1_def = request |> Map.put("switch_id", switch_2.id)

    request = %{
      "name" => "prod",
      "pipeline_path" => "./prod.yml",
      "predefined_env_vars" => %{},
      "deployment_target" => "production"
    }

    assert {:ok, _target_2} = TargetQueries.insert(request, switch_2)
    tg2_def = request |> Map.put("switch_id", switch_2.id)

    tg_defs_2 = [tg1_def, tg2_def]
    params_2 = {sw_2_def, tg_defs_2}

    {:ok, %{id_1: switch_1.id, params_1: params_1, params_2: params_2, id_2: switch_2.id}}
  end

  test "creates SwitchProcesses for all not done Switches in db", ctx do
    assert {:stop, :normal, %{}} == DbScanner.handle_info(:scann_db, %{})

    assert {:error, {:already_started, _}} =
             SSupervisor.start_switch_process(ctx.id_1, ctx.params_1)

    assert {:error, {:already_started, _}} =
             SSupervisor.start_switch_process(ctx.id_2, ctx.params_2)
  end

  test "exits gracefuly when there are no SwitchProcesses to start", ctx do
    assert {:ok, switch_1} = SwitchQueries.get_by_id(ctx.id_1)
    assert {:ok, switch_2} = SwitchQueries.get_by_id(ctx.id_2)

    params = %{"ppl_done" => true, "ppl_result" => "passed"}
    assert {:ok, _switch_1} = SwitchQueries.update(switch_1, params)
    assert {:ok, _switch_2} = SwitchQueries.update(switch_2, params)

    assert %{active: 0} = SSupervisor.count_children()
    assert {:stop, :normal, %{}} == DbScanner.handle_info(:scann_db, %{})
    assert %{active: 0} = SSupervisor.count_children()
  end

  test "does not create additional processes when process is already started for some Switch",
       ctx do
    assert {:ok, pid1} = SSupervisor.start_switch_process(ctx.id_1, ctx.params_1)

    assert %{active: 1} = SSupervisor.count_children()
    assert {:stop, :normal, %{}} == DbScanner.handle_info(:scann_db, %{})
    assert %{active: 2} = SSupervisor.count_children()

    assert {:error, {:already_started, pid2}} =
             SSupervisor.start_switch_process(ctx.id_1, ctx.params_1)

    assert pid1 == pid2

    assert {:error, {:already_started, _}} =
             SSupervisor.start_switch_process(ctx.id_2, ctx.params_2)
  end
end
