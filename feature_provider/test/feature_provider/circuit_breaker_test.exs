defmodule FeatureProvider.CircuitBreakerTest do
  use ExUnit.Case
  doctest FeatureProvider.CircuitBreaker, import: true

  import ExUnit.CaptureLog

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

    test "opens after `failure_threshold` unavailable loads in a row" do
      fail(3, probe_failing())

      assert CircuitBreaker.open?(@breaker)
    end

    test "an answer from the provider resets the count of unavailable loads in a row" do
      fail(2, probe_failing())
      CircuitBreaker.record_available(@breaker)
      fail(2, probe_failing())

      refute CircuitBreaker.open?(@breaker)
    end

    # The probe is delayed past the end of the test, so only the callers below
    # touch the count.
    @tag breaker_opts: [probe_base_ms: 60_000, probe_max_ms: 60_000]
    test "only one of many callers failing at the same time opens it" do
      breaker = Process.whereis(@breaker)
      test_pid = self()
      # The second `{:opened, ...}` clause ignores a duplicate, so count the
      # casts the breaker receives instead of the logs or its state.
      :erlang.trace(breaker, true, [:receive])

      callers =
        for i <- 1..100 do
          spawn_link(fn ->
            receive do
              :go -> :ok
            end

            CircuitBreaker.record_unavailable(@breaker, {:key, i}, {:error, :unavailable}, fn -> {:error, :unavailable} end)
            send(test_pid, {:done, self()})
          end)
        end

      capture_log(fn ->
        Enum.each(callers, &send(&1, :go))
        for caller <- callers, do: assert_receive({:done, ^caller}, 1_000)

        :sys.get_state(@breaker)
      end)

      ref = :erlang.trace_delivered(breaker)
      assert_receive {:trace_delivered, ^breaker, ^ref}, 1_000

      assert :ets.lookup(@breaker, :failures) == [{:failures, 100}]
      assert CircuitBreaker.open?(@breaker)
      assert_received {:trace, ^breaker, :receive, {:"$gen_cast", {:opened, _, _, _}}}
      refute_received {:trace, ^breaker, :receive, {:"$gen_cast", {:opened, _, _, _}}}
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

    test "only an unavailable probe counts as failed, any other result closes the breaker" do
      test_pid = self()
      {:ok, results} = Agent.start_link(fn -> [{:error, :unavailable}, {:error, {:unavailable, :timeout}}, :error] end)

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

    test "a raising, exiting or throwing probe closes the breaker without crashing it" do
      pid = Process.whereis(@breaker)

      for probe <- [fn -> raise "bug" end, fn -> exit(:bug) end, fn -> throw(:bug) end] do
        fail(3, probe)
        assert CircuitBreaker.open?(@breaker)
        eventually(fn -> refute CircuitBreaker.open?(@breaker) end)
      end

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

    test "logs the key and the result that opened it" do
      log =
        capture_log(fn ->
          CircuitBreaker.record_unavailable(@breaker, :key_1, {:error, :unavailable}, probe_failing())
          CircuitBreaker.record_unavailable(@breaker, :key_2, {:error, :unavailable}, probe_failing())
          CircuitBreaker.record_unavailable(@breaker, :key_3, {:error, {:unavailable, :timeout}}, probe_failing())
          :sys.get_state(@breaker)
        end)

      assert log =~
               ":test_breaker opened after 3 unavailable loads in a row, the last for :key_3: {:error, {:unavailable, :timeout}}"
    end

    test "logs a failed probe with its result" do
      log =
        capture_log(fn ->
          fail(3, fn -> {:error, {:unavailable, :econnrefused}} end)
          Process.sleep(100)
        end)

      assert log =~ "probe for :my_key failed: {:error, {:unavailable, :econnrefused}}"
    end

    test "logs a probe that hangs as timed out" do
      log =
        capture_log(fn ->
          fail(3, fn -> Process.sleep(:infinity) end)
          Process.sleep(200)
        end)

      assert log =~ "probe for :my_key failed: timed out after 100ms"
    end

    test "opening again while open keeps the current round of probes and its backoff" do
      fail(3, probe_failing())
      assert_receive :probed, 500
      assert_receive :probed, 500
      eventually(fn -> assert :sys.get_state(@breaker).attempt >= 2 end)

      CircuitBreaker.record_available(@breaker)
      fail(3, probe_failing())

      assert :sys.get_state(@breaker).attempt >= 2
      assert CircuitBreaker.open?(@breaker)
    end
  end

  describe "start_link/1" do
    @describetag :not_started

    for threshold <- [0, -1, 1.5, "3", nil] do
      test "rejects `failure_threshold: #{inspect(threshold)}`" do
        capture_log(fn ->
          assert {:error, reason} =
                   start_supervised({CircuitBreaker, Keyword.put(@opts, :failure_threshold, unquote(threshold))})

          assert inspect(reason) =~ "failure_threshold must be a positive integer"
        end)
      end
    end

    for key <- [:probe_base_ms, :probe_max_ms, :probe_timeout_ms], value <- [0, -1, 1.5, "100", nil] do
      test "rejects `#{key}: #{inspect(value)}`" do
        capture_log(fn ->
          assert {:error, reason} =
                   start_supervised({CircuitBreaker, Keyword.put(@opts, unquote(key), unquote(value))})

          assert inspect(reason) =~ "#{unquote(key)} must be a positive integer"
        end)
      end
    end

    test "rejects `probe_max_ms` less than `probe_base_ms`" do
      capture_log(fn ->
        assert {:error, reason} =
                 start_supervised({CircuitBreaker, Keyword.merge(@opts, probe_base_ms: 100, probe_max_ms: 50)})

        assert inspect(reason) =~ "probe_max_ms must not be less than probe_base_ms"
      end)
    end
  end

  describe "when it isn't running" do
    @describetag :not_started

    test "is reported as closed and ignores successes and failures" do
      assert :ok = CircuitBreaker.record_unavailable(@breaker, :my_key, {:error, :unavailable}, probe_failing())
      assert :ok = CircuitBreaker.record_available(@breaker)
      refute CircuitBreaker.open?(@breaker)
    end
  end

  describe "when it stops" do
    test "kills a running probe" do
      test_pid = self()

      fail(3, fn ->
        send(test_pid, {:probed, self()})
        Process.sleep(:infinity)
      end)

      assert_receive {:probed, probe_pid}, 500
      ref = Process.monitor(probe_pid)

      :ok = stop_supervised(@breaker)

      assert_receive {:DOWN, ^ref, :process, ^probe_pid, _}, 500
    end
  end

  describe "child_spec/1" do
    test "uses the name as the id, so breakers with different names can run side by side" do
      start_supervised!({CircuitBreaker, Keyword.put(@opts, :name, :other_breaker)})

      CircuitBreaker.record_unavailable(:other_breaker, :my_key, {:error, :unavailable}, probe_failing())
      assert :sys.get_state(:other_breaker).name == :other_breaker
      refute CircuitBreaker.open?(@breaker)
    end
  end

  describe "after a restart" do
    test "starts closed" do
      fail(3, probe_failing())
      assert CircuitBreaker.open?(@breaker)

      :ok = stop_supervised(@breaker)
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
    for _ <- 1..times, do: CircuitBreaker.record_unavailable(@breaker, :my_key, {:error, :unavailable}, probe)
  end

  defp probe_failing, do: probe_returning({:error, :unavailable})

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
