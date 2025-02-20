defmodule Looper.StateWatch.Impl.Test do
  use ExUnit.Case, async: false

  import Mock

  alias Looper.STM.Test.Items
  alias Looper.Test.EctoRepo
  alias Looper.StateWatch.Impl
  alias Looper.Util


  setup do
    assert {:ok, _} = Util.clean_test_db()
    :ok
  end

  test "counts events in included states and calls Watchmen.submit with valid params" do
    Enum.map(Range.new(0, 4), fn _ -> new_item("stateA") |> EctoRepo.insert() end)
    Enum.map(Range.new(0, 9), fn _ -> new_item("stateB") |> EctoRepo.insert() end)
    Enum.map(Range.new(0, 7), fn _ -> new_item("stateC") |> EctoRepo.insert() end)

    params = %{schema: Looper.STM.Test.Items, repo: Looper.Test.EctoRepo,
               included_states: ["stateA", "stateB", "stateC"], external_metric: :skip}

    pid = self()

    with_mock Watchman, [submit: &(mocked_submit(&1, &2, pid))] do
      Impl.body(params)
    end

    assert_received({"stateA", 5}, "Event count for items in stateA has not been sent")
    assert_received({"stateB", 10}, "Event count for items in stateB has not been sent")
    assert_received({"stateC", 8}, "Event count for items in stateC has not been sent")
  end

  test "does not count events if they are not in included state" do
    Enum.map(Range.new(0, 4), fn _ -> new_item("stateA") |> EctoRepo.insert() end)
    Enum.map(Range.new(0, 9), fn _ -> new_item("stateB") |> EctoRepo.insert() end)
    Enum.map(Range.new(0, 7), fn _ -> new_item("stateC") |> EctoRepo.insert() end)

    params = %{schema: Looper.STM.Test.Items, repo: Looper.Test.EctoRepo,
               included_states: ["stateA"], external_metric: :skip}

    pid = self()

    with_mock Watchman, [submit: &(mocked_submit(&1, &2, pid))] do
      Impl.body(params)
    end

    assert_received({"stateA", 5}, "Event count for items in stateA has not been sent")
    refute_received({"stateB", 10}, "Event count for items in excluded stateB has been sent")
    refute_received({"stateC", 8}, "Event count for items in excluded stateC has been sent")
  end

  test "sends external metrics with configured name" do
    Enum.map(Range.new(0, 4), fn _ -> new_item("stateA") |> EctoRepo.insert() end)

    params = %{schema: Looper.STM.Test.Items, repo: Looper.Test.EctoRepo,
               included_states: ["stateA"], external_metric: "externalName"}

    pid = self()

    with_mock Watchman, [submit: &(mocked_submit(&1, &2, pid))] do
     Impl.body(params)
    end

    assert_received({"stateA", 5}, "Event count for items in stateA has not been sent")
    assert_received({"externalName-stateA", 5}, "External metric for items in stateA has not been sent")
  end

  def mocked_submit(names, count, pid) when is_list(names) do
    Enum.each(Keyword.keys(names), fn type ->
      name = Keyword.get(names, type)
      mocked_submit(name, count, pid, type)
    end)
  end

  def mocked_submit({metric_name, [event_name, state]}, count, pid) do
    assert metric_name == "StateWatch.events_per_state"
    assert event_name == "Items"
    send(pid, {state, count})
  end

  def mocked_submit({metric_name, [state: state]}, count, pid, :external) do
    assert metric_name == "externalName"
    send(pid, {"externalName-#{state}", count})
  end

  def mocked_submit({metric_name, [event_name, state]}, count, pid, :internal),
    do: mocked_submit({metric_name, [event_name, state]}, count, pid)

  defp new_item(state) do
    %Items{state: state, result: nil, result_reason: nil}
  end
end
