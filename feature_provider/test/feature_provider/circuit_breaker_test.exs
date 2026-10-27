defmodule FeatureProvider.CircuitBreakerTest do
  use ExUnit.Case
  doctest FeatureProvider.CircuitBreaker, import: true

  alias FeatureProvider.CircuitBreaker

  @breaker :test_breaker
  @opts [name: @breaker, failure_threshold: 3, probe_base_ms: 20, probe_max_ms: 40, probe_timeout_ms: 100]

  setup context do
    unless context[:not_started] do
      start_supervised!({CircuitBreaker, Keyword.merge(@opts, context[:breaker_opts] || [])})
    end

    :ok
  end

  describe "while closed" do
    test "starts closed" do
      refute CircuitBreaker.open?(@breaker)
    end

    test "stays closed below the failure threshold" do
      fail(2, probe_failing())

      refute CircuitBreaker.open?(@breaker)
    end

    test "opens after `failure_threshold` failures in a row" do
      fail(3, probe_failing())

      assert CircuitBreaker.open?(@breaker)
    end

    test "a success resets the count of failures in a row" do
      fail(2, probe_failing())
      CircuitBreaker.record_success(@breaker)
      fail(2, probe_failing())

      refute CircuitBreaker.open?(@breaker)
    end

    @tag breaker_opts: [failure_threshold: 1]
    test "opens on the first failure with `failure_threshold: 1`" do
      fail(1, probe_failing())

      assert CircuitBreaker.open?(@breaker)
    end
  end

  describe "while open" do
    test "probes in the background and closes when a probe succeeds" do
      fail(3, probe_returning({:ok, :back}))

      assert_receive :probed, 500
      eventually(fn -> refute CircuitBreaker.open?(@breaker) end)
    end

    test "after closing, it takes `failure_threshold` new failures to open again" do
      fail(3, probe_returning({:ok, :back}))
      assert_receive :probed, 500
      eventually(fn -> refute CircuitBreaker.open?(@breaker) end)

      fail(2, probe_failing())
      refute CircuitBreaker.open?(@breaker)

      fail(1, probe_failing())
      assert CircuitBreaker.open?(@breaker)
    end

    test "keeps probing while probes fail" do
      fail(3, probe_failing())

      assert_receive :probed, 500
      assert_receive :probed, 500
      assert_receive :probed, 500
      assert CircuitBreaker.open?(@breaker)
    end

    test "a probe returning `:error` or a non-`{:ok, _}` value counts as failed" do
      test_pid = self()
      results = Agent.start_link(fn -> [:error, :whatever, {:ok, :back}] end) |> elem(1)

      probe = fn ->
        send(test_pid, :probed)
        Agent.get_and_update(results, fn [result | rest] -> {result, rest} end)
      end

      fail(3, probe)

      assert_receive :probed, 500
      assert_receive :probed, 500
      assert CircuitBreaker.open?(@breaker)
      assert_receive :probed, 500
      eventually(fn -> refute CircuitBreaker.open?(@breaker) end)
    end

    test "a raising, exiting or throwing probe counts as failed and doesn't crash the breaker" do
      test_pid = self()
      pid = Process.whereis(@breaker)

      fail(3, fn ->
        send(test_pid, :probed)
        raise "provider down"
      end)

      assert_receive :probed, 500
      fail(1, fn -> exit(:provider_down) end)
      fail(1, fn -> throw(:provider_down) end)

      Process.sleep(150)
      assert CircuitBreaker.open?(@breaker)
      assert Process.alive?(pid)
    end

    test "a probe that hangs is killed after `probe_timeout_ms` and probed again" do
      test_pid = self()

      fail(3, fn ->
        send(test_pid, {:probed, self()})
        Process.sleep(:infinity)
      end)

      assert_receive {:probed, probe_pid}, 500
      ref = Process.monitor(probe_pid)
      assert_receive {:DOWN, ^ref, :process, ^probe_pid, :killed}, 500
      assert_receive {:probed, _}, 500
      assert CircuitBreaker.open?(@breaker)
    end

    test "opening again while open keeps the current round of probes and its backoff" do
      fail(3, probe_failing())
      assert_receive :probed, 500
      assert_receive :probed, 500
      eventually(fn -> assert :sys.get_state(@breaker).attempt >= 2 end)

      CircuitBreaker.record_success(@breaker)
      fail(3, probe_failing())

      assert :sys.get_state(@breaker).attempt >= 2
      assert CircuitBreaker.open?(@breaker)
    end
  end

  describe "when it isn't running" do
    @describetag :not_started

    test "is reported as closed and ignores successes and failures" do
      assert :ok = CircuitBreaker.record_failure(@breaker, probe_failing())
      assert :ok = CircuitBreaker.record_success(@breaker)
      refute CircuitBreaker.open?(@breaker)
    end
  end

  describe "after a restart" do
    test "starts closed" do
      fail(3, probe_failing())
      assert CircuitBreaker.open?(@breaker)

      :ok = stop_supervised(CircuitBreaker)
      refute CircuitBreaker.open?(@breaker)

      start_supervised!({CircuitBreaker, @opts})
      refute CircuitBreaker.open?(@breaker)
    end
  end

  describe "probe_delay/3" do
    test "is between half and all of the backoff, which doubles up to the maximum" do
      for _ <- 1..200 do
        assert CircuitBreaker.probe_delay(0, 1_000, 60_000) in 500..1_000
        assert CircuitBreaker.probe_delay(1, 1_000, 60_000) in 1_000..2_000
        assert CircuitBreaker.probe_delay(3, 1_000, 60_000) in 4_000..8_000
        assert CircuitBreaker.probe_delay(10, 1_000, 60_000) in 30_000..60_000
        assert CircuitBreaker.probe_delay(1_000, 1_000, 60_000) in 30_000..60_000
      end
    end

    test "is at least 1ms" do
      assert CircuitBreaker.probe_delay(0, 1, 1) == 1
    end

    test "is randomized" do
      delays = for _ <- 1..50, do: CircuitBreaker.probe_delay(5, 1_000, 60_000)

      assert length(Enum.uniq(delays)) > 1
    end
  end

  defp fail(times, probe) do
    for _ <- 1..times, do: CircuitBreaker.record_failure(@breaker, probe)
  end

  defp probe_failing, do: probe_returning({:error, :provider_down})

  defp probe_returning(result, message \\ :probed) do
    test_pid = self()

    fn ->
      send(test_pid, message)
      result
    end
  end

  defp eventually(assertion, attempts \\ 50) do
    assertion.()
  rescue
    error in ExUnit.AssertionError ->
      if attempts == 0, do: reraise(error, __STACKTRACE__)
      Process.sleep(10)
      eventually(assertion, attempts - 1)
  end
end
