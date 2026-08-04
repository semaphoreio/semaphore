defmodule GithubNotifier.StatusGuard do
  @moduledoc """
  Cross-instance ordering guard for commit status delivery, backed by Redis.

  One state key per check records the last delivered state; a lease key
  holding a random token serializes concurrent deliveries across instances.
  `claim/3` is a single atomic script: a stale PENDING after a terminal state
  is skipped, a live lease reports busy, otherwise the caller acquires the
  lease and must `finalize/3` (send succeeded, record state) or `release/2`
  (send definitively failed) with its token. A stale token is a no-op, so an
  expired claimant cannot overwrite newer state. When the outcome of a send is
  unknown (timeout, transport error), the lease is deliberately NOT released —
  it expires on its own after the send could no longer land.

  Every operation fails open: on any Redis error callers deliver unguarded.
  Guard state is protection, not source of truth — RabbitMQ redelivery and
  live pipeline describes remain the durability story. The Redis instance must
  run with `maxmemory-policy noeviction`; `HealthCheck` pins the guard to
  fail-open and alarms if it does not.
  """

  require Logger

  @lease_ms 90_000
  @state_ttl_ms :timer.hours(24 * 7)
  @dedupe_ttl_ms :timer.hours(5)
  @command_timeout 1_000

  @claim_script """
  local last = redis.call('GET', KEYS[1])
  if ARGV[1] == '1' and (last == 'success' or last == 'failure') then
    redis.call('PEXPIRE', KEYS[1], ARGV[4])
    return 'skip'
  end
  if redis.call('SET', KEYS[2], ARGV[2], 'NX', 'PX', ARGV[3]) then
    return 'deliver'
  end
  return redis.call('PTTL', KEYS[2])
  """

  @finalize_script """
  if redis.call('GET', KEYS[2]) == ARGV[1] then
    redis.call('SET', KEYS[1], ARGV[2], 'PX', ARGV[3])
    redis.call('DEL', KEYS[2])
    return 1
  end
  return 0
  """

  @release_script """
  if redis.call('GET', KEYS[2]) == ARGV[1] then
    redis.call('DEL', KEYS[2])
    return 1
  end
  return 0
  """

  def child_spec(_arg) do
    children =
      for index <- 0..(pool_size() - 1) do
        Supervisor.child_spec(
          {Redix, host: host(), port: port(), name: conn_name(index)},
          id: {Redix, index}
        )
      end

    %{
      id: __MODULE__,
      type: :supervisor,
      start: {Supervisor, :start_link, [children, [strategy: :one_for_one, name: __MODULE__]]}
    }
  end

  @doc """
  Acquires the delivery lease for the check.

  Returns `{:ok, token}` when the caller may deliver, `:skip` when the status
  is a stale pending that must not be delivered, `{:busy, remaining_ms}` while
  another delivery holds the lease, or `{:error, term}` (caller fails open).
  """
  @spec claim(String.t(), String.t(), keyword()) ::
          {:ok, String.t()} | :skip | {:busy, non_neg_integer()} | {:error, term()}
  def claim(status_key, state, opts \\ []) do
    if forced_fail_open?() do
      {:error, :misconfigured}
    else
      token = :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
      pending_flag = if state == "pending", do: "1", else: "0"
      lease_ms = Keyword.get(opts, :lease_ms, @lease_ms)

      args = [pending_flag, token, Integer.to_string(lease_ms), Integer.to_string(@state_ttl_ms)]

      case eval(status_key, @claim_script, args) do
        {:ok, "skip"} -> :skip
        {:ok, "deliver"} -> {:ok, token}
        {:ok, remaining} when is_integer(remaining) -> {:busy, max(remaining, 0)}
        {:ok, other} -> {:error, {:unexpected_reply, other}}
        {:error, _} = error -> error
      end
    end
  end

  @doc """
  Records the delivered state and clears the lease. A stale token is a no-op;
  Redis errors are logged, never raised — the lease self-expires.
  """
  @spec finalize(String.t(), String.t(), String.t()) :: :ok
  def finalize(status_key, state, token) do
    args = [token, state, Integer.to_string(@state_ttl_ms)]

    case eval(status_key, @finalize_script, args) do
      {:ok, 1} ->
        :ok

      {:ok, 0} ->
        Logger.warning("[StatusGuard] stale token on finalize, state not recorded: #{status_key}")
        :ok

      {:error, reason} ->
        Logger.warning("[StatusGuard] finalize failed: #{inspect(reason)}")
        :ok
    end
  end

  @doc """
  Clears the lease without recording a delivery. Only call when the send
  definitively did not happen; on unknown outcomes let the lease expire.
  """
  @spec release(String.t(), String.t()) :: :ok
  def release(status_key, token) do
    case eval(status_key, @release_script, [token]) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        Logger.warning("[StatusGuard] release failed: #{inspect(reason)}")
        :ok
    end
  end

  @doc "Cross-instance dedupe check; errors read as not-delivered."
  @spec delivered?(String.t()) :: boolean()
  def delivered?(dedupe_key) do
    case command(dedupe_key, ["GET", dedupe_redis_key(dedupe_key)]) do
      {:ok, nil} -> false
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  @doc "Marks a status as delivered for sibling instances; errors are logged."
  @spec mark_delivered(String.t()) :: :ok
  def mark_delivered(dedupe_key) do
    ttl = Integer.to_string(@dedupe_ttl_ms)

    case command(dedupe_key, ["SET", dedupe_redis_key(dedupe_key), "1", "PX", ttl]) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        Logger.warning("[StatusGuard] mark_delivered failed: #{inspect(reason)}")
        :ok
    end
  end

  @doc false
  def forced_fail_open?, do: :persistent_term.get({__MODULE__, :forced_fail_open}, false)

  @doc false
  def force_fail_open(flag) when is_boolean(flag),
    do: :persistent_term.put({__MODULE__, :forced_fail_open}, flag)

  @doc false
  def conn_name(index), do: :"status_guard_redis_#{index}"

  @doc false
  def pool_size, do: Application.get_env(:github_notifier, :cache_pool_size, 3)

  defp eval(status_key, script, args) do
    keys = [state_key(status_key), lease_key(status_key)]
    command(status_key, ["EVAL", script, "2"] ++ keys ++ args)
  end

  defp command(routing_key, redis_command) do
    conn = conn_name(:erlang.phash2(routing_key, pool_size()))

    try do
      Redix.command(conn, redis_command, timeout: @command_timeout)
    catch
      :exit, reason -> {:error, {:exit, reason}}
    end
  end

  defp state_key(status_key), do: "#{prefix()}guard/state:#{status_key}"
  defp lease_key(status_key), do: "#{prefix()}guard/lease:#{status_key}"
  defp dedupe_redis_key(dedupe_key), do: "#{prefix()}guard/dedupe:#{dedupe_key}"

  defp prefix, do: Application.get_env(:github_notifier, :cache_prefix, "github_notifier/")
  defp host, do: Application.get_env(:github_notifier, :cache_host, "localhost")
  defp port, do: Application.get_env(:github_notifier, :cache_port, 6379)
end
