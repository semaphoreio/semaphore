defmodule Zebra.Workers.Scheduler.TriggerTest do
  use ExUnit.Case, async: true

  alias Zebra.Workers.Scheduler.Trigger

  @delay 30

  #
  # Every pass reports {:pass_started, org_id, mode, pid, at} to the test and,
  # when `blocking` is set, waits for {:release, outcome} before returning that
  # outcome.
  #
  defp start_trigger(opts \\ []) do
    test = self()
    blocking = Keyword.get(opts, :blocking, false)
    outcomes = Keyword.get(opts, :outcomes, fn _org, _mode -> :done end)

    run = fn org_id, {mode, _timeout} ->
      send(test, {:pass_started, org_id, mode, self(), System.monotonic_time(:millisecond)})

      if blocking do
        receive do
          {:release, outcome} -> outcome
        after
          5_000 -> :done
        end
      else
        outcomes.(org_id, mode)
      end
    end

    {:ok, sup} = Task.Supervisor.start_link()

    {:ok, pid} =
      Trigger.start_link(
        name: :"trigger_#{System.unique_integer([:positive])}",
        run: run,
        task_supervisor: sup,
        delay: @delay,
        max_concurrency: Keyword.get(opts, :max_concurrency, 3),
        lock_wait_timeout: 1_000
      )

    pid
  end

  defp request(pid, org_id) do
    send(self(), {:requested, org_id, System.monotonic_time(:millisecond)})
    Trigger.request(org_id, pid)
  end

  defp passes(timeout \\ 200), do: collect([], timeout)

  defp collect(acc, timeout) do
    receive do
      {:pass_started, org, mode, _pid, at} -> collect([{org, mode, at} | acc], timeout)
    after
      timeout -> Enum.reverse(acc)
    end
  end

  defp wait_idle(pid), do: Trigger.await_idle(pid, 1_000)

  test "a request runs one pass after the delay" do
    pid = start_trigger()
    t0 = System.monotonic_time(:millisecond)

    request(pid, "org-1")

    assert [{"org-1", :try, at}] = passes()
    assert at - t0 >= @delay
    assert wait_idle(pid) == :ok
  end

  test "a burst of requests for one organization costs at most two passes, the last one after every request" do
    pid = start_trigger()

    for _ <- 1..200, do: request(pid, "org-1")
    last_request = System.monotonic_time(:millisecond)

    runs = passes(300)

    assert length(runs) in 1..2
    assert Enum.all?(runs, fn {org, mode, _} -> org == "org-1" and mode == :try end)

    {_, _, last_pass} = List.last(runs)
    assert last_pass - last_request >= @delay

    assert wait_idle(pid) == :ok
  end

  test "a request while a pass runs leads to exactly one more pass after it" do
    pid = start_trigger(blocking: true)

    request(pid, "org-1")
    assert_receive {:pass_started, "org-1", :try, task, _}, 1_000

    # several requests arrive while the pass is running
    request(pid, "org-1")
    request(pid, "org-1")
    request(pid, "org-1")

    refute_receive {:pass_started, _, _, _, _}, 3 * @delay

    send(task, {:release, :done})

    assert_receive {:pass_started, "org-1", :try, second, _}, 1_000
    send(second, {:release, :done})

    refute_receive {:pass_started, _, _, _, _}, 3 * @delay
    assert wait_idle(pid) == :ok
  end

  test "no request while a pass runs => no extra pass" do
    pid = start_trigger(blocking: true)

    request(pid, "org-1")
    assert_receive {:pass_started, "org-1", :try, task, _}, 1_000
    send(task, {:release, :done})

    refute_receive {:pass_started, _, _, _, _}, 3 * @delay
    assert wait_idle(pid) == :ok
  end

  test "a request while waiting for the delay leads to one more pass" do
    pid = start_trigger()

    request(pid, "org-1")
    :timer.sleep(div(@delay, 3))
    request(pid, "org-1")
    second_request = System.monotonic_time(:millisecond)

    runs = passes(300)
    assert length(runs) == 2

    # the pass that covers the second request starts at least `delay` after it
    {_, _, last_pass} = List.last(runs)
    assert last_pass - second_request >= @delay
  end

  test "losing the lock => one retry that waits for the lock" do
    pid =
      start_trigger(
        outcomes: fn
          _org, :try -> :skipped
          _org, :wait -> :done
        end
      )

    request(pid, "org-1")

    assert [{"org-1", :try, _}, {"org-1", :wait, _}] = passes()
    assert wait_idle(pid) == :ok
  end

  test "giving up on the lock wait => no endless retries" do
    pid =
      start_trigger(
        outcomes: fn
          _org, :try -> :skipped
          _org, :wait -> :lock_timeout
        end
      )

    request(pid, "org-1")

    assert [{"org-1", :try, _}, {"org-1", :wait, _}] = passes()
    assert wait_idle(pid) == :ok
  end

  test "organizations are processed independently and in parallel" do
    pid = start_trigger(blocking: true)

    request(pid, "org-1")
    request(pid, "org-2")

    assert_receive {:pass_started, "org-1", :try, t1, _}, 1_000
    assert_receive {:pass_started, "org-2", :try, t2, _}, 1_000

    send(t1, {:release, :done})
    send(t2, {:release, :done})

    refute_receive {:pass_started, _, _, _, _}, 3 * @delay
    assert wait_idle(pid) == :ok
  end

  test "never runs more than max_concurrency passes at once, and runs the rest later" do
    pid = start_trigger(blocking: true, max_concurrency: 2)

    for i <- 1..5, do: request(pid, "org-#{i}")

    first = for _ <- 1..2, do: assert_receive({:pass_started, _, :try, _, _}, 1_000)
    refute_receive {:pass_started, _, _, _, _}, 3 * @delay
    assert Trigger.summary(pid).queued == 3

    started =
      Enum.reduce(1..3, first, fn _, [{:pass_started, _, _, task, _} | _] = acc ->
        send(task, {:release, :done})
        next = assert_receive({:pass_started, _, :try, _, _}, 1_000)
        [next | acc]
      end)

    orgs = started |> Enum.map(fn {:pass_started, org, _, _, _} -> org end) |> Enum.sort()
    assert orgs == Enum.map(1..5, &"org-#{&1}")

    Enum.each(started, fn {:pass_started, _, _, task, _} -> send(task, {:release, :done}) end)
    assert wait_idle(pid) == :ok
  end

  test "a crashing pass doesn't take the trigger down, and pending requests still run" do
    pid = start_trigger(blocking: true)

    request(pid, "org-1")
    assert_receive {:pass_started, "org-1", :try, task, _}, 1_000
    request(pid, "org-1")

    Process.exit(task, :kill)

    assert_receive {:pass_started, "org-1", :try, second, _}, 1_000
    send(second, {:release, :done})

    assert Process.alive?(pid)
    assert wait_idle(pid) == :ok
  end
end
