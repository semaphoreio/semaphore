defmodule Looper.StateResidency.Query.Test do
  use ExUnit.Case

  alias Looper.StateResidency.Test.Entity
  alias Looper.StateResidency.Test.EntityTrace
  alias Looper.Test.EctoRepo
  alias Looper.StateResidency.Query
  alias Looper.Util


  setup do
    assert {:ok, _} = Util.clean_test_db()
    :ok
  end

  test "get_durations_for_state returns valid max and p90 durations" do
    params = params(["stateA", "stateB"], "entity_traces",
                    %{"stateA" => :created_at, "stateB" => :pending_at})

    insert_test_data_to_db("stateA", :created_at)

    assert {:ok, result} = Query.get_durations_for_state(params, "stateA")
    assert result.state == "stateA"
    assert result.max_duration_ms > 5_000 and result.max_duration_ms < 5_500
    assert result.p90_duration_ms > 4_500 and result.p90_duration_ms < 5_000

    insert_test_data_to_db("stateB", :pending_at)

    assert {:ok, result} = Query.get_durations_for_state(params, "stateB")
    assert result.state == "stateB"
    assert result.max_duration_ms > 5_000 and result.max_duration_ms < 5_500
    assert result.p90_duration_ms > 4_500 and result.p90_duration_ms < 5_000
  end

  test "get_durations_for_state returns valid max and p90 durations when same table is used for trace" do
    params = params(["stateA", "stateB"], "entities",
                    %{"stateA" => :inserted_at, "stateB" => :updated_at})

    insert_test_data_to_db("stateA", :inserted_at)

    assert {:ok, result} = Query.get_durations_for_state(params, "stateA")
    assert result.state == "stateA"
    assert result.max_duration_ms > 5_000 and result.max_duration_ms < 5_500
    assert result.p90_duration_ms > 4_500 and result.p90_duration_ms < 5_000

    insert_test_data_to_db("stateB", :updated_at)

    assert {:ok, result} = Query.get_durations_for_state(params, "stateB")
    assert result.state == "stateB"
    assert result.max_duration_ms > 5_000 and result.max_duration_ms < 5_500
    assert result.p90_duration_ms > 4_500 and result.p90_duration_ms < 5_000
  end

  defp insert_test_data_to_db(state, ts_name) do
    Range.new(0, 9)
    |> Enum.map(fn _x ->
      assert {:ok, e_a1} = new_entity(state)

      [entity_id: e_a1.entity_id]
      |> Keyword.put(ts_name, DateTime.utc_now())
      |> new_entity_trace()

      :timer.sleep(500)
    end)
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
