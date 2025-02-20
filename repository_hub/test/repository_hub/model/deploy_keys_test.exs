defmodule RepositoryHub.Model.DeployKeys.Test do
  use ExUnit.Case, async: true

  alias RepositoryHub.Repo

  doctest RepositoryHub.Model.DeployKeys

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end
end
