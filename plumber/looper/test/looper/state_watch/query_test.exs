defmodule Looper.StateWatch.Query.Test do
  use ExUnit.Case

  alias Looper.STM.Test.Items
  alias Looper.Test.EctoRepo
  alias Looper.StateWatch.Query
  alias Looper.Util


  setup do
    assert {:ok, _} = Util.clean_test_db()
    :ok
  end

  test "count_events_by_state returns valid number of events per state" do
    Enum.map(Range.new(0, 4), fn _ -> new_item("stateA") |> EctoRepo.insert() end)
    Enum.map(Range.new(0, 9), fn _ -> new_item("stateB") |> EctoRepo.insert() end)
    Enum.map(Range.new(0, 7), fn _ -> new_item("stateC") |> EctoRepo.insert() end)

    states = ["stateA", "stateB", "stateC"]
    params = %{schema: Looper.STM.Test.Items, repo: Looper.Test.EctoRepo, included_states: states}

    assert {:ok, result} = Query.count_events_by_state(params)
    assert Enum.find_value(result, nil, fn x -> x == result("stateA", 5) end) != nil
    assert Enum.find_value(result, nil, fn x -> x == result("stateB", 10) end) != nil
    assert Enum.find_value(result, nil, fn x -> x == result("stateC", 8) end) != nil
  end

  test "count_events_by_state does not count excluded states" do
    Enum.map(Range.new(0, 4), fn _ -> new_item("stateA") |> EctoRepo.insert() end)
    Enum.map(Range.new(0, 9), fn _ -> new_item("stateB") |> EctoRepo.insert() end)
    Enum.map(Range.new(0, 7), fn _ -> new_item("stateC") |> EctoRepo.insert() end)

    params = %{schema: Looper.STM.Test.Items, repo: Looper.Test.EctoRepo,
               included_states: ["stateA"]}

    assert {:ok, result} = Query.count_events_by_state(params)
    assert Enum.find_value(result, nil, fn x -> x == result("stateA", 5) end) != nil
    assert Enum.find_value(result, nil, fn x -> x == result("stateB", 10) end) == nil
    assert Enum.find_value(result, nil, fn x -> x == result("stateC", 8)  end) == nil
  end

  defp result(state, number), do: {state, number}

  defp new_item(state) do
    %Items{state: state, result: nil, result_reason: nil}
  end
end
