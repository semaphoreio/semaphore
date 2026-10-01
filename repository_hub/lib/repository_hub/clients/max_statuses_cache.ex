defmodule RepositoryHub.MaxStatusesCache do
  @moduledoc """
  Per-pod tombstone cache of (owner, repo, sha, context) combinations that
  have hit GitHub's per-SHA-per-context maximum of 1000 commit statuses.

  Once a combination is recorded as maxed, `create_build_status` short-circuits
  without making the HTTP POST, since GitHub will reject it with 422 anyway and
  the request still counts against the GitHub App's rate limit.

  Entries expire after `@ttl_ms` and are not actively swept; expired entries
  are treated as misses on read. Time comparison uses
  `System.monotonic_time/1`, so the cache is meaningful only within a single
  BEAM instance — which is what "per-pod" implies.
  """

  require Logger
  use GenServer

  @table :gh_max_statuses_cache
  @ttl_ms :timer.hours(24)

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    :ets.new(@table, [:set, :public, :named_table, read_concurrency: true])
    {:ok, %{}}
  end

  @doc "Returns true if the (owner, repo, sha, context) combo has been marked maxed within the TTL."
  def maxed?(owner, repo, sha, context) do
    if table_present?() do
      case :ets.lookup(@table, key(owner, repo, sha, context)) do
        [{_, expires_at}] -> expires_at > now_ms()
        _ -> false
      end
    else
      log_missing_table(:maxed?)
      false
    end
  end

  @doc "Records that a (owner, repo, sha, context) combo has reached GitHub's status limit."
  def mark_maxed(owner, repo, sha, context) do
    if table_present?() do
      :ets.insert(@table, {key(owner, repo, sha, context), now_ms() + @ttl_ms})
      :ok
    else
      log_missing_table(:mark_maxed)
      :ok
    end
  end

  defp table_present?, do: :ets.whereis(@table) != :undefined

  # The cache table is missing — typically because the GenServer hasn't started
  # yet, or crashed and is being restarted. Both reads and writes silently
  # degrade to "no cache available" so callers keep working, but this is
  # operationally important: while the table is gone, every status post will
  # again hit GitHub and burn a rate-limit unit, which is the exact bug this
  # module exists to prevent. Emit a metric so it's alertable.
  defp log_missing_table(operation) do
    Watchman.increment("github_api.max_statuses_cache.table_missing")
    Logger.warning("MaxStatusesCache ETS table missing; operation=#{operation} degraded to no-op")
  end

  defp key(owner, repo, sha, context), do: {owner, repo, sha, context}
  defp now_ms, do: System.monotonic_time(:millisecond)
end
