defmodule BranchHub.Model.Branches.Test do
  use ExUnit.Case, async: true

  alias BranchHub.Repo

  doctest BranchHub.Model.Branches

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end
end
