defmodule Looper.Beholder.Query.Test do
  use ExUnit.Case, async: false

  import Ecto.Query
  import Mock

  alias Looper.STM.Test.Items
  alias Looper.Test.EctoRepo
  alias Looper.Beholder.Impl
  alias Looper.Util

  @threshold_count 5

  setup do
    assert {:ok, _} = Util.clean_test_db()
    :ok
  end

  test "sends external metrics with configured name" do
    Enum.map(Range.new(0, 4), fn ind -> new_item("stateA", ind) |> EctoRepo.insert() end)
    Enum.map(Range.new(5, 9), fn ind -> new_item("stateB", ind) |> EctoRepo.insert() end)
    Enum.map(Range.new(10, 14), fn ind -> new_stuck_item("stateB", ind) |> EctoRepo.insert() end)

    pid = self()

    params = %{query: Looper.STM.Test.Items, repo: Looper.Test.EctoRepo, excluded_states: [],
               threshold_sec: -1, threshold_count: @threshold_count, terminal_state: "stateC",
               result_on_abort: "failed", result_reason_on_abort: "stuck", callback: :pass,
               external_metric: "externalName"}

    with_mock Watchman, [increment: &(mocked_increment(&1, pid))] do
      Impl.body(params)
    end

    Range.new(10, 14) |> Enum.map( fn _ ->
      assert_received({"stateC"}, "Counter for stateC was not incremented")
      assert_received({"externalName-stateC"}, "External metric for items in stateC has not been sent")
    end)
  end

  def mocked_increment(names, pid) when is_list(names) do
    Enum.each(Keyword.keys(names), fn type ->
      name = Keyword.get(names, type)
      mocked_increment(name, pid, type)
    end)
  end

  def mocked_increment({metric_name, [event_name, state, reason]}, pid) do
    assert metric_name == "StateWatch.events_per_state"
    assert event_name == "Items"
    assert state == "stateC"
    assert reason == "failed-stuck"
    send(pid, {state})
  end

  def mocked_increment({metric_name, [state: state, result: reason]}, pid, :external) do
    assert metric_name == "externalName"
    assert state == "stateC"
    assert reason == "failed-stuck"
    send(pid, {"externalName-#{state}"})
  end

  def mocked_increment({metric_name, [event_name, state, reason]}, pid, :internal),
    do: mocked_increment({metric_name, [event_name, state, reason]}, pid)

  test "callback function is called after items are aborted but with original state" do
    Enum.map(Range.new(0, 4), fn ind -> new_item("stateA", ind) |> EctoRepo.insert() end)
    Enum.map(Range.new(5, 9), fn ind -> new_item("stateB", ind) |> EctoRepo.insert() end)
    Enum.map(Range.new(10, 14), fn ind -> new_stuck_item("stateB", ind) |> EctoRepo.insert() end)

    pid = self()

    params = %{query: Looper.STM.Test.Items, repo: Looper.Test.EctoRepo, excluded_states: [],
               threshold_sec: -1, threshold_count: @threshold_count, terminal_state: "stateC",
               result_on_abort: "failed", result_reason_on_abort: "stuck", external_metric: :skip,
               callback: (fn item ->
                           %{state: state, description: desc} = item

                           assert item_in_db = get_item_by_description(desc)
                           assert item != item_in_db
                           assert item_in_db.state == "stateC"
                           assert item_in_db.result == "failed"

                            case state do
                              "stateA" -> item
                              "stateB" ->
                                  assert %{"index" => ind} = desc
                                  send(pid, "Called for #{inspect ind}" |> String.to_atom())
                            end
                          end)
              }

    Impl.body(params)

    Range.new(10, 14)
    |> Enum.map(fn ind -> {:"Called for #{ind}", "Was not called for #{ind}"} end)
    |> Enum.each(fn {expected, error} -> assert_received(expected, error) end)
  end

  defp new_item(state, ind) do
    %Items{state: state, recovery_count: 0, in_scheduling: false, description: %{index: ind}}
  end

  defp new_stuck_item(state, ind) do
    %Items{state: state, recovery_count: @threshold_count, in_scheduling: true,
           description: %{index: ind}}
  end

  defp get_item_by_description(desc) do
    Looper.STM.Test.Items
    |> where([i], i.description == ^desc)
    |> EctoRepo.one()
  end

end
