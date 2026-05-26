defmodule RepositoryHub.MaxStatusesCacheTest do
  use ExUnit.Case, async: false

  alias RepositoryHub.MaxStatusesCache

  test "miss before mark, hit after mark, miss for a different key" do
    {owner, repo, sha, ctx} = {"o", "r", "abc123", "ci/test"}

    refute MaxStatusesCache.maxed?(owner, repo, sha, ctx)

    :ok = MaxStatusesCache.mark_maxed(owner, repo, sha, ctx)

    assert MaxStatusesCache.maxed?(owner, repo, sha, ctx)
    refute MaxStatusesCache.maxed?(owner, repo, sha, "other-ctx")
    refute MaxStatusesCache.maxed?(owner, repo, "different-sha", ctx)
  end
end
