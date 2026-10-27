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
    failed load is counted; a successful load resets the count.
  - **Open**: after `failure_threshold` failed loads in a row, the breaker opens.
    Cache misses no longer call the provider; the cache serves the last known
    value (see `stale_ttl_ms` in `FeatureProvider.CachexCache`), or returns
    `:not_found` straight away when there is none.
  - **Probing**: while open, the breaker re-runs the failed load that opened it
    in the background. Requests never wait for it. The first probe runs
    `probe_base_ms` after opening; each failed probe doubles the delay, up to
    `probe_max_ms`. Every delay is randomized between half and all of that
    value, so pods don't probe the provider at the same time.
  - A successful probe closes the breaker and stores its result in the cache.

  A load fails when the provider returns `{:error, _}` (or `:error`), raises,
  exits or throws. A provider that turns errors into `{:ok, []}` is never seen
  as failing.

  The state is kept in a public ETS table, so checking it doesn't go through the
  breaker process. If the breaker isn't running, it is treated as closed: the
  cache behaves as if no breaker was configured.

  ## Options

  - `name` - (required) an atom, used for the process and its ETS table
  - `failure_threshold` - failed loads in a row that open the breaker. Defaults to `#{@default_failure_threshold}`
  - `probe_base_ms` - delay before the first probe. Defaults to `#{@default_probe_base_ms}`
  - `probe_max_ms` - maximum delay between probes. Defaults to `#{@default_probe_max_ms}`
  - `probe_timeout_ms` - a probe still running after this long is killed and
    counted as failed. Defaults to `#{@default_probe_timeout_ms}`
  """
  use GenServer

  require Logger

  @type name :: atom()
  @type probe :: (() -> {:ok, any()} | any())

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
  Resets the count of failed loads in a row.

  ## Examples

      iex> record_success(:not_started_breaker)
      :ok
  """
  @spec record_success(name()) :: :ok
  def record_success(name) do
    case :ets.lookup(name, :failures) do
      [{:failures, 0}] -> :ok
      _ -> true = :ets.insert(name, {:failures, 0})
    end

    :ok
  rescue
    ArgumentError -> :ok
  end

  @doc """
  Counts a failed load. When the count reaches `failure_threshold`, opens the
  breaker and starts probing with `probe`, which succeeds when it returns
  `{:ok, _}`.

  ## Examples

      iex> record_failure(:not_started_breaker, fn -> {:ok, :value} end)
      :ok
  """
  @spec record_failure(name(), probe()) :: :ok
  def record_failure(name, probe) when is_function(probe, 0) do
    [{:failure_threshold, failure_threshold}] = :ets.lookup(name, :failure_threshold)

    # `update_counter` returns each count once, so only one caller opens it.
    if :ets.update_counter(name, :failures, 1) == failure_threshold do
      true = :ets.insert(name, {:state, :open})
      GenServer.cast(name, {:opened, probe})
    end

    :ok
  rescue
    ArgumentError ->
      Logger.warning("[FeatureProvider.CircuitBreaker] #{inspect(name)} is not running, the failure was not counted")

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
    failure_threshold = Keyword.get(opts, :failure_threshold, @default_failure_threshold)

    :ets.new(name, [:named_table, :public, :set, read_concurrency: true, write_concurrency: true])
    :ets.insert(name, [{:state, :closed}, {:failures, 0}, {:failure_threshold, failure_threshold}])

    {:ok,
     %{
       name: name,
       failure_threshold: failure_threshold,
       probe_base_ms: Keyword.get(opts, :probe_base_ms, @default_probe_base_ms),
       probe_max_ms: Keyword.get(opts, :probe_max_ms, @default_probe_max_ms),
       probe_timeout_ms: Keyword.get(opts, :probe_timeout_ms, @default_probe_timeout_ms),
       probe: nil,
       attempt: 0,
       running: nil
     }}
  end

  @impl GenServer
  def handle_cast({:opened, probe}, %{probe: nil} = state) do
    Logger.warning(
      "[FeatureProvider.CircuitBreaker] #{inspect(state.name)} opened after #{state.failure_threshold} failed loads in a row"
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
      {:probe_result, {:ok, _}} ->
        :ets.insert(state.name, [{:state, :closed}, {:failures, 0}])
        Logger.info("[FeatureProvider.CircuitBreaker] #{inspect(state.name)} closed, the provider is back")

        {:noreply, %{state | probe: nil, attempt: 0}}

      failure ->
        Logger.warning("[FeatureProvider.CircuitBreaker] #{inspect(state.name)} probe failed: #{inspect(failure)}")

        {:noreply, schedule_probe(%{state | attempt: state.attempt + 1})}
    end
  end

  def handle_info({:probe_timeout, ref}, %{running: {pid, ref, _}} = state) do
    # The `:DOWN` message that follows counts it as a failed probe.
    Process.exit(pid, :kill)

    {:noreply, state}
  end

  def handle_info(_message, state), do: {:noreply, state}

  defp run_probe(probe) do
    probe.()
  catch
    kind, reason -> {:error, {kind, reason}}
  end

  defp schedule_probe(state) do
    Process.send_after(self(), :probe, probe_delay(state.attempt, state.probe_base_ms, state.probe_max_ms))

    state
  end
end
