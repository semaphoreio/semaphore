defmodule Guard.CLIAuth.DeviceRateLimiter do
  @moduledoc """
  Global, cross-IP throttle for the device-grant user_code entry endpoint
  (`POST /device`).

  RFC 8628 §5.2 warns that a short user_code is brute-forceable. The primary
  defenses are the code's entropy (base-20, 8 chars) plus the per-code
  `attempt_count` lockout and short TTL enforced in the DB (both global across
  pods). This limiter is the coarse safety net on top: it counts *failed* code
  entries in a fixed time window and, past a threshold, rejects further attempts
  from everyone — not per-IP, so an attacker rotating source IPs is still capped.

  State lives in a public ETS table owned by this process (one counter per time
  bucket). It is per-instance; combined with the DB-global per-code lockout the
  fleet-wide guarantee holds even though this counter is not shared across pods.
  """

  use GenServer

  @table :cli_device_rate_limit
  @window_seconds 60
  # Max failed user_code entries tolerated per window before the endpoint locks.
  @max_failures 60

  # ── public API ──────────────────────────────────────────────────────────

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc "`:ok` if entries are still allowed this window, `{:error, :rate_limited}` otherwise."
  @spec check() :: :ok | {:error, :rate_limited}
  def check do
    if current_count() >= @max_failures, do: {:error, :rate_limited}, else: :ok
  end

  @doc "Record one failed user_code entry against the current window."
  @spec record_failure() :: :ok
  def record_failure do
    ensure_table()
    :ets.update_counter(@table, bucket(), {2, 1}, {bucket(), 0})
    :ok
  end

  @doc "Reset all counters. Test-only helper."
  @spec reset() :: :ok
  def reset do
    ensure_table()
    :ets.delete_all_objects(@table)
    :ok
  end

  @doc "Failures tolerated per window (exposed for tests)."
  @spec max_failures() :: pos_integer()
  def max_failures, do: @max_failures

  # ── GenServer ─────────────────────────────────────────────────────────────

  @impl true
  def init(:ok) do
    ensure_table()
    {:ok, %{}}
  end

  # ── internals ─────────────────────────────────────────────────────────────

  defp current_count do
    ensure_table()

    case :ets.lookup(@table, bucket()) do
      [{_bucket, count}] -> count
      [] -> 0
    end
  end

  defp bucket, do: div(System.system_time(:second), @window_seconds)

  # Create the table on demand so the limiter works even if the request process
  # races the GenServer start, or in unit tests that don't boot the supervisor.
  defp ensure_table do
    case :ets.whereis(@table) do
      :undefined ->
        try do
          :ets.new(@table, [:named_table, :public, :set, {:write_concurrency, true}])
        rescue
          ArgumentError -> :ok
        end

      _ ->
        :ok
    end

    :ok
  end
end
