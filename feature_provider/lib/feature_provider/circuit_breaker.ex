defmodule FeatureProvider.CircuitBreaker do
  @default_failure_threshold 3
  @default_probe_base_ms 5_000
  @default_probe_max_ms 60_000
  @default_probe_timeout_ms 30_000

  @moduledoc """
  A circuit breaker for a provider, used by `FeatureProvider.CachexCache`
  through its `breaker` option.

  The breaker is opt-in: it has to be started in the supervision tree of the
  service that wants it, and the cache has to be pointed at it.

      children = [
        {Cachex, name: :feature_cache},
        {FeatureProvider.CircuitBreaker, name: :feature_breaker}
      ]

      config FeatureProvider, :provider,
        {MyApp.GrpcProvider,
         [cache: {FeatureProvider.CachexCache,
                  name: :feature_cache, stale_ttl_ms: :timer.hours(24), breaker: :feature_breaker}]}

  ## How it works

  - **Closed** (the normal state): every cache miss calls the provider. Each
    load that finds the provider unavailable is counted; any other result
    resets the count.
  - **Open**: after `failure_threshold` unavailable loads in a row, the breaker opens.
    Cache misses no longer call the provider; the cache serves the last known
    value (see `stale_ttl_ms` in `FeatureProvider.CachexCache`), or returns
    `:not_found` straight away when there is none.
  - **Probing**: while open, the breaker re-runs the load that opened it
    in the background. Requests never wait for it. The first probe runs
    `probe_base_ms` after opening; each unavailable probe doubles the delay, up to
    `probe_max_ms`. Every delay is randomized between half and all of that
    value, so pods don't probe the provider at the same time.
  - Any other probe result closes the breaker: the provider answered. A
    successful probe also stores its result in the cache.

  The provider is unavailable when a load returns `{:error, :unavailable}` or
  `{:error, {:unavailable, reason}}` (see `unavailable?/1`). Return it for
  errors that mean the provider can't be reached, such as a gRPC `UNAVAILABLE`
  or `DEADLINE_EXCEEDED`, a refused connection or a timeout. Any other error,
  and a raise, exit or throw, is an answer about that key: it falls back to
  the last known value in the cache, but doesn't count towards opening the
  breaker. This way a key that the provider keeps rejecting, such as an unknown
  organization, can't open the breaker for every other key.

  The state is kept in a public ETS table, so checking it doesn't go through the
  breaker process. If the breaker isn't running, it is treated as closed: the
  cache behaves as if no breaker was configured.

  ## Options

  - `name` - (required) an atom, used for the process and its ETS table
  - `failure_threshold` - unavailable loads in a row that open the breaker, a
    positive integer. Defaults to `#{@default_failure_threshold}`
  - `probe_base_ms` - delay before the first probe, a positive integer.
    Defaults to `#{@default_probe_base_ms}`
  - `probe_max_ms` - maximum delay between probes, a positive integer not less
    than `probe_base_ms`. Defaults to `#{@default_probe_max_ms}`
  - `probe_timeout_ms` - a probe still running after this long is killed and
    counted as failed, a positive integer. Defaults to `#{@default_probe_timeout_ms}`
  """
  use GenServer

  require Logger

  @type name :: atom()
  @type probe :: (() -> {:ok, any()} | any())

  @doc """
  Returns `true` for a load result that means the provider is unavailable.

  ## Examples

      iex> unavailable?({:error, :unavailable})
      true
      iex> unavailable?({:error, {:unavailable, :econnrefused}})
      true
      iex> unavailable?({:error, :not_found})
      false
      iex> unavailable?({:ok, []})
      false
  """
  @spec unavailable?(any()) :: boolean()
  def unavailable?({:error, :unavailable}), do: true
  def unavailable?({:error, {:unavailable, _}}), do: true
  def unavailable?(_), do: false

  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)

    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Returns `true` when the breaker is open. A breaker that isn't running is
  reported as closed.

  ## Examples

      iex> open?(:not_started_breaker)
      false
  """
  @spec open?(name()) :: boolean()
  def open?(name) do
    match?([{:state, :open}], :ets.lookup(name, :state))
  rescue
    ArgumentError -> false
  end

  @doc """
  Records a load the provider answered, successfully or not: resets the count
  of unavailable loads in a row.

  ## Examples

      iex> record_available(:not_started_breaker)
      :ok
  """
  @spec record_available(name()) :: :ok
  def record_available(name) do
    case :ets.lookup(name, :failures) do
      [{:failures, 0}] -> :ok
      _ -> true = :ets.insert(name, {:failures, 0})
    end

    :ok
  rescue
    ArgumentError -> :ok
  end

  @doc """
  Counts a load that found the provider unavailable. When the count reaches
  `failure_threshold`, opens the breaker and starts probing with `probe`, which
  closes the breaker unless its result is `unavailable?/1`.

  ## Examples

      iex> record_unavailable(:not_started_breaker, fn -> {:ok, :value} end)
      :ok
  """
  @spec record_unavailable(name(), probe()) :: :ok
  def record_unavailable(name, probe) when is_function(probe, 0) do
    [{:failure_threshold, failure_threshold}] = :ets.lookup(name, :failure_threshold)

    # `update_counter` returns each count once, so only one caller opens it.
    if :ets.update_counter(name, :failures, 1) == failure_threshold do
      true = :ets.insert(name, {:state, :open})
      GenServer.cast(name, {:opened, probe})
    end

    :ok
  rescue
    ArgumentError ->
      Logger.debug("[FeatureProvider.CircuitBreaker] #{inspect(name)} is not running, the failure was not counted")

      :ok
  end

  @doc false
  # The delay before probe number `attempt` (starting at 0): the backoff
  # doubles up to `max_ms`, and the delay is randomized between half and all
  # of it.
  @spec probe_delay(non_neg_integer(), pos_integer(), pos_integer()) :: pos_integer()
  def probe_delay(attempt, base_ms, max_ms) do
    backoff = min(max_ms, base_ms * Integer.pow(2, min(attempt, 20)))
    half = div(backoff, 2)

    half + :rand.uniform(backoff - half)
  end

  @impl GenServer
  def init(opts) do
    name = Keyword.fetch!(opts, :name)
    # With anything else, `update_counter/3` never returns it and the breaker
    # never opens.
    failure_threshold = positive_integer!(opts, :failure_threshold, @default_failure_threshold)
    # With anything else, scheduling a probe crashes the breaker when it opens.
    probe_base_ms = positive_integer!(opts, :probe_base_ms, @default_probe_base_ms)
    probe_max_ms = positive_integer!(opts, :probe_max_ms, @default_probe_max_ms)
    probe_timeout_ms = positive_integer!(opts, :probe_timeout_ms, @default_probe_timeout_ms)

    if probe_max_ms < probe_base_ms do
      raise ArgumentError,
            "probe_max_ms must not be less than probe_base_ms, got: #{probe_max_ms} < #{probe_base_ms}"
    end

    :ets.new(name, [:named_table, :public, :set, read_concurrency: true, write_concurrency: true])
    :ets.insert(name, [{:state, :closed}, {:failures, 0}, {:failure_threshold, failure_threshold}])

    {:ok,
     %{
       name: name,
       failure_threshold: failure_threshold,
       probe_base_ms: probe_base_ms,
       probe_max_ms: probe_max_ms,
       probe_timeout_ms: probe_timeout_ms,
       probe: nil,
       attempt: 0,
       running: nil
     }}
  end

  @impl GenServer
  def handle_cast({:opened, probe}, %{probe: nil} = state) do
    Logger.warning(
      "[FeatureProvider.CircuitBreaker] #{inspect(state.name)} opened after #{state.failure_threshold} unavailable loads in a row"
    )

    {:noreply, schedule_probe(%{state | probe: probe, attempt: 0})}
  end

  # Opened again by failures that were already in flight: keep the current
  # round of probes and its backoff.
  def handle_cast({:opened, probe}, state) do
    {:noreply, %{state | probe: probe}}
  end

  @impl GenServer
  def handle_info(:probe, %{probe: probe, running: nil} = state) when is_function(probe, 0) do
    {pid, ref} = spawn_monitor(fn -> exit({:probe_result, run_probe(probe)}) end)
    timer = Process.send_after(self(), {:probe_timeout, ref}, state.probe_timeout_ms)

    {:noreply, %{state | running: {pid, ref, timer}}}
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, %{running: {_, ref, timer}} = state) do
    Process.cancel_timer(timer)
    state = %{state | running: nil}

    case reason do
      {:probe_result, result} ->
        if unavailable?(result) do
          probe_failed(reason, state)
        else
          :ets.insert(state.name, [{:state, :closed}, {:failures, 0}])
          Logger.info("[FeatureProvider.CircuitBreaker] #{inspect(state.name)} closed, the provider is back")

          {:noreply, %{state | probe: nil, attempt: 0}}
        end

      # Killed after `probe_timeout_ms`.
      killed ->
        probe_failed(killed, state)
    end
  end

  def handle_info({:probe_timeout, ref}, %{running: {pid, ref, _}} = state) do
    # The `:DOWN` message that follows counts it as a failed probe.
    Process.exit(pid, :kill)

    {:noreply, state}
  end

  def handle_info(_message, state), do: {:noreply, state}

  # A raise, exit or throw is an answer, like in the cache, so it closes the
  # breaker.
  defp run_probe(probe) do
    probe.()
  catch
    kind, reason -> {:error, {kind, reason}}
  end

  defp probe_failed(reason, state) do
    Logger.warning(
      "[FeatureProvider.CircuitBreaker] #{inspect(state.name)} probe failed: #{format_failure(reason, state)}"
    )

    {:noreply, schedule_probe(%{state | attempt: state.attempt + 1})}
  end

  defp format_failure({:probe_result, result}, _state), do: inspect(result)
  defp format_failure(:killed, state), do: "timed out after #{state.probe_timeout_ms}ms"
  defp format_failure(reason, _state), do: inspect(reason)

  defp positive_integer!(opts, key, default) do
    case Keyword.get(opts, key, default) do
      value when is_integer(value) and value > 0 ->
        value

      other ->
        raise ArgumentError, "#{key} must be a positive integer, got: #{inspect(other)}"
    end
  end

  defp schedule_probe(state) do
    Process.send_after(self(), :probe, probe_delay(state.attempt, state.probe_base_ms, state.probe_max_ms))

    state
  end
end
