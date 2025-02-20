defmodule Gofer.TargetTrigger.Engine.DbScanner.Test do
  use ExUnit.Case

  alias Gofer.Target.Model.TargetQueries
  alias Gofer.Switch.Model.SwitchQueries
  alias Gofer.SwitchTrigger.Model.SwitchTriggerQueries
  alias Gofer.TargetTrigger.Model.TargetTriggerQueries
  alias Gofer.TargetTrigger.Engine.TargetTriggerSupervisor, as: TTSupervisor
  alias Gofer.TargetTrigger.Engine.DbScanner

  setup do
    assert {:ok, _} = Ecto.Adapters.SQL.query(Gofer.EctoRepo, "truncate table switches cascade;")
    start_supervised!(TTSupervisor)

    assert {:ok, switch} =
             SwitchQueries.insert(%{
               "id" => UUID.uuid4(),
               "ppl_id" => UUID.uuid4(),
               "prev_ppl_artefact_ids" => [],
               "branch_name" => "master"
             })

    request = %{"name" => "stg", "pipeline_path" => "./stg.yml"}
    assert {:ok, _target_1} = TargetQueries.insert(request, switch)

    request = %{"name" => "stg-2", "pipeline_path" => "./stg-2.yml"}
    assert {:ok, _target_2} = TargetQueries.insert(request, switch)

    request = %{"name" => "prod", "pipeline_path" => "./prod.yml"}
    assert {:ok, _target_3} = TargetQueries.insert(request, switch)

    sw_tg = %{
      "switch_id" => switch.id,
      "triggered_by" => "user1",
      "triggered_at" => DateTime.utc_now(),
      "target_names" => ["stg", "prod"],
      "request_token" => "asdf",
      "id" => UUID.uuid4()
    }

    assert {:ok, switch_trigger} = SwitchTriggerQueries.insert(sw_tg)

    params = %{
      "switch_id" => switch.id,
      "switch_trigger_id" => switch_trigger.id,
      "target_name" => "stg"
    }

    assert {:ok, targ_tg_stg} = TargetTriggerQueries.insert(params)

    params = %{
      "switch_id" => switch.id,
      "switch_trigger_id" => switch_trigger.id,
      "target_name" => "prod"
    }

    assert {:ok, targ_tg_prod} = TargetTriggerQueries.insert(params)

    {:ok, %{switch_trigger: switch_trigger, targ_tg_stg: targ_tg_stg, targ_tg_prod: targ_tg_prod}}
  end

  test "creates TargetTriggerProcesses for all unprocessed TargetTriggers in db", ctx do
    assert {:stop, :normal, %{}} == DbScanner.handle_info(:scann_db, %{})

    assert {:error, {:already_started, _}} =
             TTSupervisor.start_target_trigger_process(ctx.switch_trigger.id, "prod")

    assert {:error, {:already_started, _}} =
             TTSupervisor.start_target_trigger_process(ctx.switch_trigger.id, "stg")
  end

  test "exits gracefuly when there are no TargetTriggerProcesses to start", ctx do
    assert {:ok, tg_tg_1} = TargetTriggerQueries.get_by_id_and_name(ctx.switch_trigger.id, "prod")
    assert {:ok, tg_tg_2} = TargetTriggerQueries.get_by_id_and_name(ctx.switch_trigger.id, "stg")

    assert {:ok, _tgtg} = TargetTriggerQueries.update(tg_tg_1, %{"processed" => true})
    assert {:ok, _tgtg} = TargetTriggerQueries.update(tg_tg_2, %{"processed" => true})

    assert %{active: 0} = TTSupervisor.count_children()
    assert {:stop, :normal, %{}} == DbScanner.handle_info(:scann_db, %{})
    assert %{active: 0} = TTSupervisor.count_children()
  end

  test "does not create additional processes when process is already started for some TargetTrigger",
       ctx do
    assert {:ok, pid1} = TTSupervisor.start_target_trigger_process(ctx.switch_trigger.id, "prod")

    assert %{active: 1} = TTSupervisor.count_children()
    assert {:stop, :normal, %{}} == DbScanner.handle_info(:scann_db, %{})
    assert %{active: 2} = TTSupervisor.count_children()

    assert {:error, {:already_started, pid2}} =
             TTSupervisor.start_target_trigger_process(ctx.switch_trigger.id, "prod")

    assert pid1 == pid2

    assert {:error, {:already_started, _}} =
             TTSupervisor.start_target_trigger_process(ctx.switch_trigger.id, "stg")
  end
end
