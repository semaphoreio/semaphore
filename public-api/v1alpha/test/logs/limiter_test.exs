defmodule PipelinesAPI.Logs.Limiter.Test do
  use ExUnit.Case, async: true

  alias PipelinesAPI.Logs.Limiter

  defp start_limiter(max) do
    name = :"logs_limiter_#{System.unique_integer([:positive])}"
    start_supervised!({Limiter, name: name, max_concurrent: max})
    name
  end

  # A process that holds a slot until told to finish.
  defp hold(limiter) do
    test = self()

    pid =
      spawn(fn ->
        Limiter.run(limiter, fn ->
          send(test, {:holding, self()})

          receive do
            :finish -> :ok
            :crash -> raise "boom"
          end
        end)
      end)

    assert_receive {:holding, ^pid}
    pid
  end

  defp eventually_in_use(limiter, expected, tries \\ 50) do
    cond do
      Limiter.in_use(limiter) == expected -> :ok
      tries == 0 -> flunk("in_use is #{Limiter.in_use(limiter)}, expected #{expected}")
      true -> Process.sleep(10) && eventually_in_use(limiter, expected, tries - 1)
    end
  end

  test "up to the cap, every caller runs and gets fun's result" do
    limiter = start_limiter(2)
    holder = hold(limiter)

    assert Limiter.run(limiter, fn -> :ran end) == :ran
    assert Limiter.in_use(limiter) == 1

    send(holder, :finish)
  end

  test "over the cap, the caller is turned away without running fun" do
    limiter = start_limiter(1)
    holder = hold(limiter)

    assert Limiter.run(limiter, fn -> flunk("must not run") end) == {:error, :busy}

    send(holder, :finish)
  end

  test "a slot is freed when fun returns" do
    limiter = start_limiter(1)
    holder = hold(limiter)

    send(holder, :finish)
    eventually_in_use(limiter, 0)
    assert Limiter.run(limiter, fn -> :ran end) == :ran
  end

  test "a slot is freed when fun raises" do
    limiter = start_limiter(1)
    assert_raise RuntimeError, fn -> Limiter.run(limiter, fn -> raise "boom" end) end
    assert Limiter.in_use(limiter) == 0
  end

  # What cowboy does to the request process when the client hangs up: no
  # after block runs, only the monitor frees the slot.
  test "a slot is freed when its holder is killed" do
    limiter = start_limiter(1)
    holder = hold(limiter)

    Process.exit(holder, :kill)
    eventually_in_use(limiter, 0)
    assert Limiter.run(limiter, fn -> :ran end) == :ran
  end

  test "a slot is freed when its holder crashes" do
    limiter = start_limiter(1)
    holder = hold(limiter)

    send(holder, :crash)
    eventually_in_use(limiter, 0)
  end

  test "callers are turned away, not crashed, when the limiter is down" do
    limiter = start_limiter(1)
    stop_supervised!(Limiter)
    refute Process.whereis(limiter)

    assert Limiter.run(limiter, fn -> flunk("must not run") end) == {:error, :busy}
  end

  test "the app's limiter uses the configured size" do
    assert :sys.get_state(Limiter).max ==
             Application.fetch_env!(:pipelines_api, :logs_max_concurrent)
  end
end
