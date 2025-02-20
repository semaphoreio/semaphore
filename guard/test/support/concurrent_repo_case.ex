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

    :ok
  end
end
