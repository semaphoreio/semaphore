defmodule Gofer.Actions.ListTriggersImpl.Test do
  use ExUnit.Case

  alias Gofer.Actions
  alias Gofer.Target.Model.TargetQueries
  alias Gofer.Switch.Model.SwitchQueries
  alias Gofer.SwitchTrigger.Model.SwitchTriggerQueries
  alias Gofer.TargetTrigger.Model.TargetTriggerQueries
  alias Gofer.Switch.Engine.SwitchSupervisor, as: SSupervisor
  alias Gofer.SwitchTrigger.Engine.SwitchTriggerSupervisor, as: STSupervisor
  alias Gofer.TargetTrigger.Engine.TargetTriggerSupervisor, as: TTSupervisor
  alias Test.Helpers

  @grpc_port 50060

  setup_all do
    GRPC.Server.start(Test.MockPlumberService, @grpc_port)

    on_exit(fn ->
      GRPC.Server.stop(Test.MockPlumberService)
    end)

    {:ok, %{}}
  end

  setup do
    assert {:ok, _} = Ecto.Adapters.SQL.query(Gofer.EctoRepo, "truncate table switches cascade;")

    switch_def = %{
      "id" => UUID.uuid4(),
      "ppl_id" => UUID.uuid4(),
      "prev_ppl_artefact_ids" => [],
      "branch_name" => "master"
    }

    target_1 = %{
      "name" => "staging",
      "pipeline_path" => "./stg.yml",
      "predefined_env_vars" => %{},
      "auto_trigger_on" => [%{"result" => "passed", "branch" => ["mast.", "xyz"]}]
    }

    target_2 = %{"name" => "prod", "pipeline_path" => "./prod.yml", "predefined_env_vars" => %{}}
    targets_defs = [target_1, target_2]

    start_supervised!(SSupervisor)
    start_supervised!(STSupervisor)
    start_supervised!(TTSupervisor)

    {:ok, %{switch_def: switch_def, targets_defs: targets_defs}}
  end

  # ListTriggerEvents

  test "list_triggers() returns correct page with result for valid params", ctx do
    Helpers.use_test_plumber_service(@grpc_port)
    Helpers.test_plumber_service_schedule_response("valid")

    assert {:ok, switch} = SwitchQueries.insert(ctx.switch_def)

    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(0), switch)
    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(1), switch)

    SwitchQueries.update(switch, %{"ppl_done" => true, "ppl_result" => "passed"})

    "123456789"
    |> String.codepoints()
    |> Enum.map(fn ind -> trigger_targets(switch.id, ind) end)

    assert {:ok, result} = Actions.list_triggers(switch.id, "prod", 2, 3)
    assert result.page_number == 2
    assert result.page_size == 3
    assert result.total_entries == 9
    assert result.total_pages == 3
    assert trigger_events_correct(result.trigger_events, 3, ["6", "5", "4"])
  end

  test "list_triggers() returns triggers for all targets when target_name is omitted", ctx do
    Helpers.use_test_plumber_service(@grpc_port)
    Helpers.test_plumber_service_schedule_response("valid")

    assert {:ok, switch} = SwitchQueries.insert(ctx.switch_def)

    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(0), switch)
    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(1), switch)

    SwitchQueries.update(switch, %{"ppl_done" => true, "ppl_result" => "passed"})

    "12345678"
    |> String.codepoints()
    |> Enum.map(fn ind -> trigger_targets(switch.id, ind) end)

    assert {:ok, result} = Actions.list_triggers(switch.id, :skip, 2, 4)
    assert result.page_number == 2
    assert result.page_size == 4
    assert result.total_entries == 16
    assert result.total_pages == 4
    assert trigger_events_correct(result.trigger_events, 4, ["6", "6", "5", "5"])
  end

  test "list_triggers() returns all result when there is less of them than requested", ctx do
    Helpers.use_test_plumber_service(@grpc_port)
    Helpers.test_plumber_service_schedule_response("valid")

    assert {:ok, switch} = SwitchQueries.insert(ctx.switch_def)

    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(0), switch)
    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(1), switch)

    SwitchQueries.update(switch, %{"ppl_done" => true, "ppl_result" => "passed"})

    "123"
    |> String.codepoints()
    |> Enum.map(fn ind -> trigger_targets(switch.id, ind) end)

    assert {:ok, result} = Actions.list_triggers(switch.id, "prod", 1, 10)
    assert result.page_number == 1
    assert result.page_size == 10
    assert result.total_entries == 3
    assert result.total_pages == 1
    assert trigger_events_correct(result.trigger_events, 3, ["3", "2", "1"])
  end

  test "list_triggers() returns total 0  when there are no triggers for given target", ctx do
    assert {:ok, switch} = SwitchQueries.insert(ctx.switch_def)

    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(0), switch)
    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(1), switch)

    assert {:ok, result} = Actions.list_triggers(switch.id, "staging", 1, 10)

    assert result == %{
             trigger_events: [],
             page_number: 1,
             page_size: 10,
             total_entries: 0,
             total_pages: 1
           }

    assert {:ok, result} = Actions.list_triggers(switch.id, "prod", 1, 10)

    assert result == %{
             trigger_events: [],
             page_number: 1,
             page_size: 10,
             total_entries: 0,
             total_pages: 1
           }
  end

  test "list_triggers() returns total 0 when called with wrong target name", ctx do
    assert {:ok, switch} = SwitchQueries.insert(ctx.switch_def)

    assert {:ok, result} = Actions.list_triggers(switch.id, "some-target", 1, 10)

    assert result == %{
             trigger_events: [],
             page_number: 1,
             page_size: 10,
             total_entries: 0,
             total_pages: 1
           }
  end

  test "list_triggers() returns :NOT_FOUND when wrong switch_id is given" do
    id = UUID.uuid4()
    assert {:ok, {:NOT_FOUND, message}} = Actions.list_triggers(id, "prod", 1, 10)
    assert message == "Switch with id #{id} not found."
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
end
