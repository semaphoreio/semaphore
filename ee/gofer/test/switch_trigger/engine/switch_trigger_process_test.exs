defmodule Gofer.SwitchTrigger.Engine.SwitchTriggerProcess.Test do
  use ExUnit.Case

  alias Gofer.Target.Model.TargetQueries
  alias Gofer.Switch.Model.SwitchQueries
  alias Gofer.SwitchTrigger.Model.SwitchTriggerQueries
  alias Gofer.TargetTrigger.Model.TargetTriggerQueries
  alias Gofer.SwitchTrigger.Engine.SwitchTriggerProcess, as: STP
  alias Gofer.TargetTrigger.Engine.TargetTriggerProcess, as: TTP
  alias Gofer.TargetTrigger.Engine.TargetTriggerSupervisor, as: TTSupervisor

  setup do
    assert {:ok, _} = Ecto.Adapters.SQL.query(Gofer.EctoRepo, "truncate table switches cascade;")

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
      "id" => UUID.uuid4(),
      "switch_id" => switch.id,
      "triggered_by" => "user1",
      "triggered_at" => DateTime.utc_now(),
      "target_names" => ["stg", "prod"],
      "request_token" => "asdf"
    }

    assert {:ok, switch_trigger} = SwitchTriggerQueries.insert(sw_tg)

    start_supervised!(TTSupervisor)

    {:ok, %{switch_trigger: switch_trigger, params: sw_tg}}
  end

  test "can not start two STPs for same switch_trigger_id", ctx do
    assert {:ok, pid} = STP.start_link({ctx.switch_trigger.id, ctx.params})

    assert {:error, {:already_started, pid_2}} =
             STP.start_link({ctx.switch_trigger.id, ctx.params})

    assert pid == pid_2
  end

  test "STP exits gracefully when there is no switch_trigger in db" do
    id = UUID.uuid4()
    assert {:stop, :normal, %{id: id}} == STP.handle_info(:trigger_targets, %{id: id})
  end

  test "STP exits gracefully when switch_trigger was already processed", ctx do
    assert {:ok, sw_tg} = SwitchTriggerQueries.mark_as_processed(ctx.switch_trigger)
    assert true == sw_tg.processed

    id = sw_tg.id
    assert {:stop, :normal, %{id: id}} == STP.handle_info(:trigger_targets, %{id: id})
  end

  test "STP creates target_trigger db entries and starts TTPs when given valid params", ctx do
    id = ctx.switch_trigger.id
    assert {:stop, :normal, %{id: id}} == STP.handle_info(:trigger_targets, %{id: id})

    assert {:ok, _target_trigger} = TargetTriggerQueries.get_by_id_and_name(id, "stg")
    assert {:error, {:already_started, _pid}} = TTP.start_link({id, "stg"})

    assert {:ok, _target_trigger} = TargetTriggerQueries.get_by_id_and_name(id, "prod")
    assert {:error, {:already_started, _pid}} = TTP.start_link({id, "prod"})
  end

  test "STP creates target_trigger db entries and starts TTPs even if some of db entries already exist",
       ctx do
    params = form_tt_insert_params(ctx.switch_trigger, "stg")
    assert {:ok, _target_trigger} = TargetTriggerQueries.insert(params)

    id = ctx.switch_trigger.id
    assert {:stop, :normal, %{id: id}} == STP.handle_info(:trigger_targets, %{id: id})

    assert {:ok, _target_trigger} = TargetTriggerQueries.get_by_id_and_name(id, "stg")
    assert {:error, {:already_started, _pid}} = TTP.start_link({id, "stg"})

    assert {:ok, _target_trigger} = TargetTriggerQueries.get_by_id_and_name(id, "prod")
    assert {:error, {:already_started, _pid}} = TTP.start_link({id, "prod"})
  end

  defp form_tt_insert_params(switch_trigger, target_name) do
    %{
      "switch_id" => switch_trigger.switch_id,
      "switch_trigger_id" => switch_trigger.id,
      "target_name" => target_name
    }
  end

  test "STP creates target_trigger db entries and starts TTPs even if some of TTPs are already started",
       ctx do
    id = ctx.switch_trigger.id

    params = form_tt_insert_params(ctx.switch_trigger, "stg")
    assert {:ok, _target_trigger} = TargetTriggerQueries.insert(params)
    assert {:ok, _pid} = TTP.start_link({id, "stg"})

    assert {:stop, :normal, %{id: id}} == STP.handle_info(:trigger_targets, %{id: id})

    assert {:ok, _target_trigger} = TargetTriggerQueries.get_by_id_and_name(id, "stg")
    assert {:error, {:already_started, _pid}} = TTP.start_link({id, "stg"})

    assert {:ok, _target_trigger} = TargetTriggerQueries.get_by_id_and_name(id, "prod")
    assert {:error, {:already_started, _pid}} = TTP.start_link({id, "prod"})
  end
end
