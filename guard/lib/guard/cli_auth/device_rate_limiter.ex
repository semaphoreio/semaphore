defmodule Guard.CLIAuth.DeviceRateLimiter do
  @moduledoc """
  Throttle for the device-grant user_code entry endpoint (`POST /device`).

  RFC 8628 §5.2 warns that a short user_code is brute-forceable. The primary
  defenses are the code's entropy (base-20, 8 chars) plus the per-code
  `attempt_count` lockout and short TTL enforced in the DB (both global across
  pods). This limiter is the coarse safety net on top, with two tiers:

    * **per-IP** — counts failed code entries from a single requester IP in a
      fixed time window and, past a (low) threshold, rejects further attempts
      from that IP only. This is what actually contains a single attacker: it
      can't DoS every other device sign-in by burning the shared budget.
    * **global** — the pre-existing cross-IP backstop: counts failed entries
      from *any* IP and, past a (high) threshold, locks the endpoint for
      everyone. Kept because an attacker rotating source IPs would otherwise
      evade the per-IP tier entirely; this catches that distributed case.

  Callers without an IP (or during tests) can omit it — the per-IP tier is
  simply skipped and only the global backstop applies, same as before this
  tier existed.

  State lives in public ETS tables owned by this process (one counter per
  time bucket, or per {ip, bucket} for the per-IP tier). It is per-instance;
  combined with the DB-global per-code lockout the fleet-wide guarantee holds
  even though these counters are not shared across pods.
  """

  use GenServer

  @table :cli_device_rate_limit
  @ip_table :cli_device_rate_limit_ip
  @window_seconds 60
  # Max failed user_code entries tolerated per window before the endpoint
  # locks for everyone (global backstop).
  @max_failures 60
  # Max failed user_code entries tolerated per window from a single IP before
  # that IP is throttled. Deliberately well under @max_failures so one noisy
  # attacker trips its own limit long before it could exhaust the shared one.
  @max_failures_per_ip 10

  # ── public API ──────────────────────────────────────────────────────────

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc """
  `:ok` if entries are still allowed this window, `{:error, :rate_limited}`
  otherwise. Checks the per-IP tier (when `ip` is given) as well as the
  global backstop; either one tripping rejects the request.
  """
  @spec check(String.t() | nil) :: :ok | {:error, :rate_limited}
  def check(ip \\ nil) do
    cond do
      current_count() >= @max_failures -> {:error, :rate_limited}
      ip != nil and current_count_for_ip(ip) >= @max_failures_per_ip -> {:error, :rate_limited}
      true -> :ok
    end
  end

  @doc "Record one failed user_code entry against the current window (global and, when given, per-IP)."
  @spec record_failure(String.t() | nil) :: :ok
  def record_failure(ip \\ nil) do
    ensure_table()
    :ets.update_counter(@table, bucket(), {2, 1}, {bucket(), 0})

    if ip != nil do
      ensure_ip_table()
      :ets.update_counter(@ip_table, {ip, bucket()}, {2, 1}, {{ip, bucket()}, 0})
    end

    :ok
  end

  @doc "Reset all counters. Test-only helper."
  @spec reset() :: :ok
  def reset do
    ensure_table()
    ensure_ip_table()
    :ets.delete_all_objects(@table)
    :ets.delete_all_objects(@ip_table)
    :ok
  end

  @doc "Failures tolerated per window, globally (exposed for tests)."
  @spec max_failures() :: pos_integer()
  def max_failures, do: @max_failures

  @doc "Failures tolerated per window, per IP (exposed for tests)."
  @spec max_failures_per_ip() :: pos_integer()
  def max_failures_per_ip, do: @max_failures_per_ip

  # ── GenServer ─────────────────────────────────────────────────────────────

  @impl true
  def init(:ok) do
    ensure_table()
    ensure_ip_table()
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

  defp current_count_for_ip(ip) do
    ensure_ip_table()

    case :ets.lookup(@ip_table, {ip, bucket()}) do
      [{_key, count}] -> count
      [] -> 0
    end
  end

  defp bucket, do: div(System.system_time(:second), @window_seconds)

  # Create the tables on demand so the limiter works even if the request
  # process races the GenServer start, or in unit tests that don't boot the
  # supervisor.
  defp ensure_table, do: ensure_named_table(@table)
  defp ensure_ip_table, do: ensure_named_table(@ip_table)

  defp ensure_named_table(name) do
    case :ets.whereis(name) do
      :undefined ->
        try do
          :ets.new(name, [:named_table, :public, :set, {:write_concurrency, true}])
        rescue
          ArgumentError -> :ok
        end

      _ ->
        :ok
    end

    :ok
  end
end
