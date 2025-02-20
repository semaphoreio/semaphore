defmodule Looper.StateResidency.Impl.Test do
  use ExUnit.Case, async: false

  import Mock

  alias Looper.StateResidency.Test.Entity
  alias Looper.StateResidency.Test.EntityTrace
  alias Looper.Test.EctoRepo
  alias Looper.StateResidency.Impl
  alias Looper.Util


  setup do
    assert {:ok, _} = Util.clean_test_db()
    :ok
  end

  test "calculates residency duration for entities and calls Watchmen.submit with valid params" do
    params = params(["stateA", "stateB"], "entity_traces",
                    %{"stateA" => :created_at, "stateB" => :pending_at})

    {:ok, e_a1} = new_entity("stateA")
    ts_a1 = DateTime.utc_now()
    new_entity_trace([entity_id: e_a1.entity_id, created_at: ts_a1])

    {:ok, e_a2} = new_entity("stateA")
    ts_a2 = DateTime.utc_now()
    new_entity_trace([entity_id: e_a2.entity_id, created_at: ts_a2])

    {:ok, e_b1} = new_entity("stateB")
    ts_b1 = DateTime.utc_now()
    new_entity_trace([entity_id: e_b1.entity_id, pending_at: ts_b1])

    {:ok, e_b2} = new_entity("stateB")
    ts_b2 = DateTime.utc_now()
    new_entity_trace([entity_id: e_b2.entity_id, pending_at: ts_b2])

    {:ok, e_a1} = new_entity("stateC")
    ts_a1 = DateTime.utc_now()
    new_entity_trace([entity_id: e_a1.entity_id, created_at: ts_a1])

    pid = self()

    with_mock Watchman, [submit: &(mocked_submit(&1, &2, pid))] do
      Impl.body(params)
    end

    assert_received({"stateA", :max_duration_ms, _}, "Max residency duration for items in stateA has not been sent")
    assert_received({"stateA", :p90_duration_ms, _}, "P90 residency duration for items in stateA has not been sent")
    assert_received({"stateB", :max_duration_ms, _}, "Max residency duration for items in stateB has not been sent")
    assert_received({"stateB", :p90_duration_ms, _}, "P90 residency duration for items in stateB has not been sent")
    refute_received({"stateC", _, _}, "Residency duration for items in stateC should not have been sent")
  end

  def mocked_submit({metric_name, [event_name, state, type]}, duration, pid) do
    assert metric_name == "StateResidency.duration_per_state"
    assert event_name == "Entity"
    send(pid, {state, type, duration})
  end

  defp params(states, trace_schema, map) do
    %{
      repo:                     Looper.Test.EctoRepo,
      schema_name:              Looper.StateResidency.Test.Entity,
      schema:                   "entities",
      schema_id:                :entity_id,
      included_states:          states,
      trace_schema:             trace_schema,
      trace_schema_id:          :entity_id,
      states_to_timestamps_map: map,
    }
  end

  defp new_entity(state) do
    id = UUID.uuid4()
    entity = %Entity{state: state, entity_id: id} |> EctoRepo.insert(returning: true)
    entity
  end

  defp new_entity_trace(params) do
    EntityTrace |> struct(params) |> EctoRepo.insert(returning: true)
  end

end
