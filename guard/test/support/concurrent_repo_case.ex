# Helper module for setting up tests that can run DB queries concurrently
# withourh interfearing with each other
# https://hexdocs.pm/ecto/testing-with-ecto.html
defmodule Guard.RepoCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      import Guard.RepoCase
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Guard.Repo)
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Guard.FrontRepo)
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Guard.InstanceConfigRepo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(Guard.Repo, {:shared, self()})
      Ecto.Adapters.SQL.Sandbox.mode(Guard.FrontRepo, {:shared, self()})
      Ecto.Adapters.SQL.Sandbox.mode(Guard.InstanceConfigRepo, {:shared, self()})
    end

    # Node-local caches are not rolled back with the sandbox transaction, so a
    # value cached by one test outlives the rows it was derived from. The
    # revoke-rate breaker counts accounts revoked in a window and caches that
    # count for a few seconds - long enough for one test's storm to trip the
    # breaker for the next test that legitimately revokes.
    Cachex.clear(:oauth_revoke_rate_cache)

    :ok
  end
end
