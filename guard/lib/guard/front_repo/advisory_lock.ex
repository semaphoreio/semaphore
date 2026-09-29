defmodule Guard.FrontRepo.AdvisoryLock do
  @moduledoc """
  Non-blocking, cross-replica mutual exclusion built on Postgres
  transaction-scoped advisory locks.

  Used to collapse a herd of concurrent OAuth token refreshes for one
  `repo_host_account` into a single provider POST. A node-local lock is not
  enough: guard runs several replicas and every one of them can serve a
  `GetRepositoryToken` call for the same account, so the mutual exclusion has
  to live somewhere both replicas can see. The Front database is already on
  the request path, and `pg_try_advisory_xact_lock/1` costs one round trip and
  no new persisted state.

  Two properties matter for the caller:

    * **Non-blocking.** `pg_try_advisory_xact_lock/1` returns `false`
      immediately instead of queueing, so a loser never sits on a pooled DB
      connection waiting for the winner's HTTP call to finish. It gets `:busy`
      back, the transaction ends, the connection returns to the pool, and the
      caller backs off outside any transaction.

    * **Transaction-scoped.** The lock is released when the transaction
      commits, rolls back, or the connection dies. There is no unlock call to
      leak and no lease to expire: a winner that crashes mid-refresh releases
      the lock with its connection.

  The flip side is that the winner holds a `Guard.FrontRepo` connection for as
  long as `fun` runs. The pool is small (`POSTGRES_FRONT_DB_POOL_SIZE`,
  defaulting to `POSTGRES_DB_POOL_SIZE`), so anything run under this lock MUST
  be bounded - see the 3s timeout on the provider token clients in
  `Guard.Api.Bitbucket` / `Guard.Api.Gitlab`.
  """

  require Logger

  alias Guard.FrontRepo

  # Namespaces the key space so an advisory lock taken here can never collide
  # with one taken by another feature (or by the Front Rails app) against the
  # same database.
  @oauth_refresh_namespace "guard:oauth_refresh:"

  # Bounds how long a statement inside the locked transaction may wait for a
  # ROW lock. Without it, a concurrent writer holding a row lock (a reconnect,
  # a revoke flip) could park the winner - and therefore the advisory lock and
  # a pooled connection - indefinitely.
  @lock_timeout_ms 3_000

  @doc """
  Run `fun` while holding the advisory lock derived from `key`.

  Returns `{:ok, result}` when the lock was taken and `fun` ran, `:busy` when
  another session already holds it (`fun` is NOT run), or `{:error, reason}`
  when the transaction itself failed.

  `fun` runs inside a `Guard.FrontRepo` transaction, so it may read and write
  through the repo; it must not block for longer than the caller is prepared
  to hold a pooled connection.
  """
  @spec transaction(String.t(), (() -> result)) :: {:ok, result} | :busy | {:error, term()}
        when result: term()
  def transaction(key, fun) when is_binary(key) and is_function(fun, 0) do
    lock_key = lock_key(key)

    FrontRepo.transaction(fn ->
      set_lock_timeout()

      if acquire(lock_key) do
        fun.()
      else
        :busy
      end
    end)
    |> case do
      {:ok, :busy} -> :busy
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, reason}
    end
  rescue
    # The pool is small and the winner holds a connection for the length of
    # its provider call, so a checkout timeout here is a foreseeable outcome
    # rather than a bug. Left to propagate it would cross the gRPC boundary as
    # INTERNAL and escape before the caller writes its negative cache entry -
    # so every retry would queue for a connection again. Hand it back as an
    # ordinary error and let the caller degrade to a retryable failure.
    #
    # Deliberately narrow: anything raised by `fun` itself still propagates.
    error in [DBConnection.ConnectionError] ->
      {:error, error}
  end

  # `SET LOCAL` is scoped to the surrounding transaction, so this cannot leak
  # onto the next checkout of this pooled connection.
  defp set_lock_timeout do
    FrontRepo.query!("SET LOCAL lock_timeout = #{@lock_timeout_ms}", [])
  end

  defp acquire(lock_key) do
    case FrontRepo.query!("SELECT pg_try_advisory_xact_lock($1)", [lock_key]) do
      %{rows: [[true]]} -> true
      _ -> false
    end
  end

  # Postgres advisory-lock keys are signed 64-bit integers. Derive one from a
  # namespaced SHA-256 of the caller's key: deterministic across replicas and
  # across OTP versions (unlike :erlang.phash2/1) and independent of the
  # server's undocumented `hashtext()`.
  @doc false
  @spec lock_key(String.t()) :: integer()
  def lock_key(key) do
    <<lock_key::signed-integer-size(64), _rest::binary>> =
      :crypto.hash(:sha256, @oauth_refresh_namespace <> key)

    lock_key
  end
end
