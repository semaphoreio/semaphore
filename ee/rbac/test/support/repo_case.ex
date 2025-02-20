# Helper module for setting up tests that can run DB queries concurrently
# withourh interfearing with each other
# https://hexdocs.pm/ecto/testing-with-ecto.html
defmodule Rbac.RepoCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      import Rbac.RepoCase
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Rbac.Repo)
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Rbac.FrontRepo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(Rbac.Repo, {:shared, self()})
      Ecto.Adapters.SQL.Sandbox.mode(Rbac.FrontRepo, {:shared, self()})
    end

    :ok
  end
end
