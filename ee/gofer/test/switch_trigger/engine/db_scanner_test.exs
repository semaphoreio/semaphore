defmodule Gofer.SwitchTrigger.Engine.DbScanner.Test do
  use ExUnit.Case

  alias Gofer.Target.Model.TargetQueries
  alias Gofer.Switch.Model.SwitchQueries
  alias Gofer.SwitchTrigger.Model.SwitchTriggerQueries
  alias Gofer.SwitchTrigger.Engine.SwitchTriggerSupervisor, as: STSupervisor
  alias Gofer.TargetTrigger.Engine.TargetTriggerSupervisor, as: TTSupervisor
  alias Gofer.SwitchTrigger.Engine.DbScanner

  setup do
    assert {:ok, _} = Ecto.Adapters.SQL.query(Gofer.EctoRepo, "truncate table switches cascade;")

    start_supervised!(
      {Test.MockDynamicSupervisor, [name: STSupervisor, call_extractor: &elem(&1, 0)]}
    )

    start_supervised!(
      {Test.MockDynamicSupervisor, [name: TTSupervisor, call_extractor: &elem(&1, 0)]}
    )

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

    sw_tg_1 = %{
      "switch_id" => switch.id,
      "triggered_by" => "user1",
      "triggered_at" => DateTime.utc_now(),
      "target_names" => ["stg", "prod"],
      "request_token" => "asdf",
      "id" => UUID.uuid4()
    }

    assert {:ok, _struct} = SwitchTriggerQueries.insert(sw_tg_1)

    sw_tg_2 = %{
      "switch_id" => switch.id,
      "triggered_by" => "user1",
      "triggered_at" => DateTime.utc_now(),
      "target_names" => ["prod"],
      "request_token" => "ghjk",
      "id" => UUID.uuid4()
    }

    assert {:ok, _struct} = SwitchTriggerQueries.insert(sw_tg_2)

    {:ok, %{sw_tg_1: sw_tg_1, sw_tg_2: sw_tg_2}}
  end

  test "creates SwitchTriggerProcesses for all unprocessed SwitchTriggers in db", ctx do
    assert {:stop, :normal, %{}} == DbScanner.handle_info(:scann_db, %{})

    assert {:error, {:already_started, _}} =
             STSupervisor.start_switch_trigger_process(Map.get(ctx.sw_tg_1, "id"), ctx.sw_tg_1)

    assert {:error, {:already_started, _}} =
             STSupervisor.start_switch_trigger_process(Map.get(ctx.sw_tg_2, "id"), ctx.sw_tg_2)
  end

  test "exits gracefuly when there are no SwitchTriggerProcesses to start", ctx do
    assert {:ok, sw_tg_1} = SwitchTriggerQueries.get_by_id(Map.get(ctx.sw_tg_1, "id"))
    assert {:ok, sw_tg_2} = SwitchTriggerQueries.get_by_id(Map.get(ctx.sw_tg_2, "id"))

    assert {:ok, _tgtg} = SwitchTriggerQueries.mark_as_processed(sw_tg_1)
    assert {:ok, _tgtg} = SwitchTriggerQueries.mark_as_processed(sw_tg_2)

    assert %{active: 0} = STSupervisor.count_children()
    assert {:stop, :normal, %{}} == DbScanner.handle_info(:scann_db, %{})
    assert %{active: 0} = STSupervisor.count_children()
  end

  test "does not create additional processes when process is already started for some SwitchTrigger",
       ctx do
    assert {:ok, pid1} =
             STSupervisor.start_switch_trigger_process(Map.get(ctx.sw_tg_1, "id"), ctx.sw_tg_1)

    assert %{active: 1} = STSupervisor.count_children()
    assert {:stop, :normal, %{}} == DbScanner.handle_info(:scann_db, %{})
    assert %{active: 2} = STSupervisor.count_children()

    assert {:error, {:already_started, pid2}} =
             STSupervisor.start_switch_trigger_process(Map.get(ctx.sw_tg_1, "id"), ctx.sw_tg_1)

    assert pid1 == pid2

    assert {:error, {:already_started, _}} =
             STSupervisor.start_switch_trigger_process(Map.get(ctx.sw_tg_2, "id"), ctx.sw_tg_2)
  end
end
