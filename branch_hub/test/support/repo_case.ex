defmodule BranchHub.RepoCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      alias BranchHub.Repo

      import Ecto
      import Ecto.Query
      import BranchHub.RepoCase
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(BranchHub.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(BranchHub.Repo, {:shared, self()})
    end

    :ok
  end
end
