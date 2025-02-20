defmodule Gofer.TargetTrigger.Engine.TargetTriggerSupervisor.Test do
  use ExUnit.Case

  alias Gofer.TargetTrigger.Engine.TargetTriggerSupervisor
  alias Test.TestGenServer

  test "it is possible to start random number of children processes dynamically and terminate them" do
    {:ok, supervisor} = TargetTriggerSupervisor.start_link([])

    children_number = :rand.uniform(10)

    processes =
      children_number
      |> Range.new(1)
      |> Enum.map(fn ind ->
        100 |> :rand.uniform() |> :timer.sleep()
        target_name = "target-" <> to_string(ind)

        assert {:ok, pid} =
                 DynamicSupervisor.start_child(supervisor, {TestGenServer, target_name})

        pid
      end)

    assert %{active: ^children_number} = TargetTriggerSupervisor.count_children()

    :timer.sleep(5_000)

    processes
    |> Enum.map(fn pid ->
      DynamicSupervisor.terminate_child(supervisor, pid)
    end)

    :timer.sleep(1_000)

    assert %{active: 0} = TargetTriggerSupervisor.count_children()
    Supervisor.stop(supervisor)
  end

  test "two child processes for same id and target_name can not be started" do
    {:ok, supervisor} = TargetTriggerSupervisor.start_link([])
    id = "123"

    assert {:ok, pid} = DynamicSupervisor.start_child(supervisor, {TestGenServer, id})

    assert {:error, {:already_started, pid}} ==
             DynamicSupervisor.start_child(supervisor, {TestGenServer, id})

    assert %{active: 1, workers: 1} = TargetTriggerSupervisor.count_children()
    Supervisor.stop(supervisor)
  end

  test "when transient child exits with :normal reason, it is not restarted" do
    {:ok, supervisor} = TargetTriggerSupervisor.start_link([])
    id = "123"

    assert {:ok, pid} = DynamicSupervisor.start_child(supervisor, {TestGenServer, id})
    :timer.sleep(1_000)

    assert %{active: 1, workers: 1} = TargetTriggerSupervisor.count_children()
    GenServer.cast(pid, {:terminate, :normal})
    :timer.sleep(1_000)

    assert %{active: 0, workers: 0} = TargetTriggerSupervisor.count_children()
    Supervisor.stop(supervisor)
  end

  test "when transient child exits with something other than :normal reason, it is restarted" do
    {:ok, supervisor} = TargetTriggerSupervisor.start_link([])
    id = "123"

    assert {:ok, pid} = DynamicSupervisor.start_child(supervisor, {TestGenServer, id})
    :timer.sleep(1_000)

    assert %{active: 1, workers: 1} = TargetTriggerSupervisor.count_children()
    GenServer.cast(pid, {:terminate, :not_normal_reason})
    :timer.sleep(1_000)

    assert Process.alive?(pid) == false
    assert %{active: 1, workers: 1} = TargetTriggerSupervisor.count_children()
    Supervisor.stop(supervisor)
  end
end
