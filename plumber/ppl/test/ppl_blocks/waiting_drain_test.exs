defmodule Ppl.PplBlocks.WaitingDrain.Test do
  use ExUnit.Case, async: false

  import Mock

  alias Ppl.PplBlocks.STMHandler.WaitingState
  alias Ppl.PplBlocks.WaitingDrain

  # Mocked drain notifies the test and waits until test releases it.
  defp drain_mock(test_pid) do
    fn ppl_id ->
      send(test_pid, {:drain_started, ppl_id, self()})

      receive do
        :release -> {:ok, 0}
        :crash -> raise "drain failed"
      end
    end
  end

  defp start_drain(max_tasks) do
    start_supervised!({Task.Supervisor, name: WaitingDrain.task_supervisor()})
    start_supervised!({WaitingDrain, [max_tasks: max_tasks]})
  end

  defp assert_drain_started(ppl_id) do
    assert_receive {:drain_started, ^ppl_id, pid}, 1_000
    pid
  end

  test "pipeline triggered multiple times while queued is drained once" do
    with_mock WaitingState, [:passthrough], drain_pipeline: drain_mock(self()) do
      start_drain(1)

      WaitingDrain.trigger("ppl-a")
      a = assert_drain_started("ppl-a")

      for _ <- 1..3, do: WaitingDrain.trigger("ppl-b")

      send(a, :release)
      b = assert_drain_started("ppl-b")
      send(b, :release)

      refute_receive {:drain_started, _, _}, 300
    end
  end

  test "pipeline triggered while it is being drained is drained once more" do
    with_mock WaitingState, [:passthrough], drain_pipeline: drain_mock(self()) do
      start_drain(2)

      WaitingDrain.trigger("ppl-a")
      a = assert_drain_started("ppl-a")

      for _ <- 1..3, do: WaitingDrain.trigger("ppl-a")

      # never drained by two tasks at the same time
      refute_receive {:drain_started, "ppl-a", _}, 300

      send(a, :release)
      a2 = assert_drain_started("ppl-a")
      send(a2, :release)

      refute_receive {:drain_started, _, _}, 300
    end
  end

  test "at most max_tasks pipelines are drained in parallel" do
    with_mock WaitingState, [:passthrough], drain_pipeline: drain_mock(self()) do
      start_drain(2)

      ~w(ppl-a ppl-b ppl-c) |> Enum.each(&WaitingDrain.trigger/1)

      a = assert_drain_started("ppl-a")
      b = assert_drain_started("ppl-b")
      refute_receive {:drain_started, "ppl-c", _}, 300

      send(b, :release)
      c = assert_drain_started("ppl-c")

      send(a, :release)
      send(c, :release)
      refute_receive {:drain_started, _, _}, 300
    end
  end

  test "crashed drain does not stop draining of other pipelines" do
    with_mock WaitingState, [:passthrough], drain_pipeline: drain_mock(self()) do
      drain_pid = start_drain(1)

      WaitingDrain.trigger("ppl-a")
      WaitingDrain.trigger("ppl-b")

      a = assert_drain_started("ppl-a")
      send(a, :crash)

      b = assert_drain_started("ppl-b")
      send(b, :release)

      assert Process.alive?(drain_pid)
    end
  end

  test "trigger without pipeline id is ignored" do
    assert :ok == WaitingDrain.trigger(nil)
  end

  test "pipelines stay queued while drain tasks can not be started" do
    with_mock WaitingState, [:passthrough], drain_pipeline: drain_mock(self()) do
      start_supervised!({WaitingDrain, [max_tasks: 3]})

      WaitingDrain.trigger("ppl-a")
      WaitingDrain.trigger("ppl-b")
      refute_receive {:drain_started, _, _}, 300

      start_supervised!({Task.Supervisor, name: WaitingDrain.task_supervisor()})
      WaitingDrain.trigger("ppl-c")

      for ppl_id <- ~w(ppl-a ppl-b ppl-c), do: ppl_id |> assert_drain_started() |> send(:release)
    end
  end

  test "with max_tasks 0 triggers only wake up periodic scheduling" do
    test_pid = self()

    with_mock WaitingState, [:passthrough],
      drain_pipeline: drain_mock(test_pid),
      execute_now: fn -> send(test_pid, :execute_now) end do
      start_drain(0)

      WaitingDrain.trigger("ppl-a")

      assert_receive :execute_now, 1_000
      refute_receive {:drain_started, _, _}, 300
    end
  end
end
