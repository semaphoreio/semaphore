defmodule RepositoryHub.MaxStatusesCacheTest do
  use ExUnit.Case, async: false

  alias RepositoryHub.MaxStatusesCache

  @table :gh_max_statuses_cache

  setup do
    if :ets.whereis(@table) != :undefined, do: :ets.delete_all_objects(@table)
    :ok
  end

  test "miss before mark, hit after mark, miss for distinct keys" do
    {owner, repo, sha, ctx} = {"o", "r", "abc123", "ci/test"}

    refute MaxStatusesCache.maxed?(owner, repo, sha, ctx)

    :ok = MaxStatusesCache.mark_maxed(owner, repo, sha, ctx)

    assert MaxStatusesCache.maxed?(owner, repo, sha, ctx)
    refute MaxStatusesCache.maxed?(owner, repo, sha, "other-ctx")
    refute MaxStatusesCache.maxed?(owner, repo, "different-sha", ctx)
    refute MaxStatusesCache.maxed?(owner, "other-repo", sha, ctx)
    refute MaxStatusesCache.maxed?("other-owner", repo, sha, ctx)
  end

  test "expired entries are treated as misses" do
    {owner, repo, sha, ctx} = {"o", "r", "expired-sha", "ci/test"}
    expired_at = System.monotonic_time(:millisecond) - 1
    :ets.insert(@table, {{owner, repo, sha, ctx}, expired_at})

    refute MaxStatusesCache.maxed?(owner, repo, sha, ctx)
  end

  # Note: we don't unit-test the absent-table path (when the GenServer is
  # down / restarting). meck cannot mock the `:ets` BIF module (sticky), and
  # actually deleting the table would race with the application supervisor
  # restarting the GenServer. The production code uses `:ets.whereis/1` to
  # check presence before reading/writing, which is straightforward enough
  # to read and review without test coverage.
end
