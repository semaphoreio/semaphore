defmodule FeatureProvider.CachexCacheTest do
  use ExUnit.Case
  doctest FeatureProvider.CachexCache, import: true

  import ExUnit.CaptureLog

  alias FeatureProvider.{CachexCache, CircuitBreaker}

  @stale [name: :my_cache, ttl_ms: 50, stale_ttl_ms: 1_000]

  setup do
    {:ok, _} = start_supervised({Cachex, name: :my_cache})
    :ok
  end

  describe "fetch/3 with `stale_ttl_ms`" do
    test "serves the last known value when the callback exits or throws" do
      load_and_expire(:key, "known")

      assert CachexCache.fetch(:key, fn -> exit(:provider_down) end, @stale) == "known"
      assert CachexCache.fetch(:key, fn -> throw(:provider_down) end, @stale) == "known"
      assert CachexCache.fetch(:key, fn -> :error end, @stale) == "known"
    end

    test "propagates a raise, exit or throw when there is no last known value" do
      assert_raise RuntimeError, "provider down", fn ->
        CachexCache.fetch(:key, fn -> raise "provider down" end, @stale)
      end

      assert catch_exit(CachexCache.fetch(:key, fn -> exit(:provider_down) end, @stale)) == :provider_down
      assert catch_throw(CachexCache.fetch(:key, fn -> throw(:provider_down) end, @stale)) == :provider_down
    end

    test "returns `:not_found` once `ttl_ms + stale_ttl_ms` has passed" do
      opts = [name: :my_cache, ttl_ms: 20, stale_ttl_ms: 30]
      assert CachexCache.fetch(:key, "known", opts) == "known"

      Process.sleep(30)
      assert CachexCache.fetch(:key, fn -> {:error, :provider_down} end, opts) == "known"

      Process.sleep(40)
      assert CachexCache.fetch(:key, fn -> {:error, :provider_down} end, opts) == :not_found
    end

    test "each successful load restarts the `ttl_ms + stale_ttl_ms` window" do
      opts = [name: :my_cache, ttl_ms: 20, stale_ttl_ms: 40]
      assert CachexCache.fetch(:key, "first", opts) == "first"

      Process.sleep(40)
      assert CachexCache.fetch(:key, "second", opts) == "second"

      Process.sleep(40)
      assert CachexCache.fetch(:key, fn -> {:error, :provider_down} end, opts) == "second"
    end

    test "serves the last known value after `invalidate` when the reload fails" do
      assert CachexCache.fetch(:key, "known", @stale) == "known"
      assert CachexCache.fetch(:key, "ignored", [invalidate: true] ++ @stale) == "known"
      assert CachexCache.get(:key, name: :my_cache) == :not_found

      assert CachexCache.fetch(:key, fn -> {:error, :provider_down} end, @stale) == "known"
    end

    test "`clear/1` drops the last known value" do
      load_and_expire(:key, "known")
      CachexCache.clear(name: :my_cache)

      assert CachexCache.fetch(:key, fn -> {:error, :provider_down} end, @stale) == :not_found
    end

    test "keeps values per key" do
      load_and_expire(:a, "a")
      load_and_expire(:b, "b")

      assert CachexCache.fetch(:a, fn -> {:error, :provider_down} end, @stale) == "a"
      assert CachexCache.fetch(:b, fn -> {:error, :provider_down} end, @stale) == "b"
      assert CachexCache.fetch(:c, fn -> {:error, :provider_down} end, @stale) == :not_found
    end

    test "logs the key and the error, with the stacktrace of an exception" do
      load_and_expire({:provide_features, "org-1"}, "known")

      log =
        capture_log(fn ->
          CachexCache.fetch({:provide_features, "org-1"}, fn -> {:error, :unavailable} end, @stale)
        end)

      assert log =~ ~s(serving last known value for {:provide_features, "org-1"}: {:error, :unavailable})

      log =
        capture_log(fn ->
          CachexCache.fetch({:provide_features, "org-1"}, fn -> raise "provider down" end, @stale)
        end)

      assert log =~ "** (RuntimeError) provider down"
      assert log =~ "cachex_cache_test.exs"
    end

    for stale_ttl_ms <- [nil, :infinity, "1000", -1, 0, 1.5] do
      test "is disabled, without crashing, for `stale_ttl_ms: #{inspect(stale_ttl_ms)}`" do
        opts = [name: :my_cache, ttl_ms: 20, stale_ttl_ms: unquote(Macro.escape(stale_ttl_ms))]

        assert CachexCache.fetch(:key, "known", opts) == "known"
        Process.sleep(30)

        assert CachexCache.fetch(:key, fn -> {:error, :provider_down} end, opts) == :not_found
      end
    end
  end

  describe "fetch/3 with `breaker`" do
    setup do
      start_supervised!({CircuitBreaker, name: :my_breaker, failure_threshold: 2, probe_base_ms: 20, probe_max_ms: 40})

      [opts: [breaker: :my_breaker] ++ @stale]
    end

    test "stops calling the callback once the breaker opens, and serves the last known value", %{opts: opts} do
      load_and_expire(:key, "known", opts)

      assert CachexCache.fetch(:key, failing_callback(), opts) == "known"
      assert CachexCache.fetch(:key, failing_callback(), opts) == "known"
      assert_received :called
      assert_received :called
      assert CircuitBreaker.open?(:my_breaker)

      assert CachexCache.fetch(:key, failing_callback(), opts) == "known"
      assert CachexCache.fetch(:key, failing_callback(), [reload: true] ++ opts) == "known"
      refute_received :called
    end

    test "returns `:not_found` without calling the callback for a key with no last known value", %{opts: opts} do
      open_breaker(opts)

      assert CachexCache.fetch(:never_loaded, fn -> raise "not called" end, opts) == :not_found
    end

    test "still serves fresh values from the cache while open", %{opts: opts} do
      assert CachexCache.fetch(:fresh, "fresh", [ttl_ms: 60_000] ++ opts) == "fresh"
      open_breaker(opts)

      assert CachexCache.fetch(:fresh, failing_callback(), opts) == "fresh"
      refute_received :called
    end

    test "counts raises, exits and throws as failures", %{opts: opts} do
      load_and_expire(:key, "known", opts)

      assert CachexCache.fetch(:key, fn -> raise "provider down" end, opts) == "known"
      assert CachexCache.fetch(:key, fn -> exit(:provider_down) end, opts) == "known"

      assert CircuitBreaker.open?(:my_breaker)
    end

    test "a successful load resets the count of failures in a row", %{opts: opts} do
      load_and_expire(:key, "known", opts)

      CachexCache.fetch(:key, failing_callback(), opts)
      CachexCache.fetch(:key, "loaded", [reload: true] ++ opts)
      CachexCache.fetch(:key, failing_callback(), [reload: true] ++ opts)

      refute CircuitBreaker.open?(:my_breaker)
    end

    test "a successful probe closes the breaker and stores its result", %{opts: opts} do
      load_and_expire(:key, "known", opts)
      {:ok, provider} = Agent.start_link(fn -> {:error, :provider_down} end)
      callback = fn -> Agent.get(provider, & &1) end

      CachexCache.fetch(:key, callback, opts)
      CachexCache.fetch(:key, callback, opts)
      assert CircuitBreaker.open?(:my_breaker)

      Agent.update(provider, fn _ -> {:ok, "back"} end)

      eventually(fn -> refute CircuitBreaker.open?(:my_breaker) end)
      assert CachexCache.get(:key, name: :my_cache) == "back"
    end

    test "logs once per failed load before opening, not on every lookup while open", %{opts: opts} do
      load_and_expire(:key, "known", opts)

      log =
        capture_log(fn ->
          for _ <- 1..10, do: CachexCache.fetch(:key, failing_callback(), opts)
        end)

      assert log |> String.split("serving last known value") |> length() == 3
    end

    test "behaves as without a breaker when the breaker isn't running", %{opts: opts} do
      :ok = stop_supervised(CircuitBreaker)
      load_and_expire(:key, "known", opts)

      for _ <- 1..5, do: assert(CachexCache.fetch(:key, failing_callback(), opts) == "known")
      for _ <- 1..5, do: assert_received(:called)
    end
  end

  defp load_and_expire(key, value, opts \\ @stale) do
    assert CachexCache.fetch(key, value, opts) == value
    Process.sleep(60)
    assert CachexCache.get(key, opts) == :not_found
  end

  defp open_breaker(opts) do
    CachexCache.fetch(:opener, fn -> {:error, :provider_down} end, opts)
    CachexCache.fetch(:opener, fn -> {:error, :provider_down} end, opts)
    assert CircuitBreaker.open?(:my_breaker)
  end

  defp failing_callback do
    test_pid = self()

    fn ->
      send(test_pid, :called)
      {:error, :provider_down}
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
