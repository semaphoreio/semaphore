defmodule RepositoryHub.ServerActionCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      alias RepositoryHub.Repo

      import Ecto
      import Ecto.Query
      import RepositoryHub.ServerActionCase

      @moduletag :integration
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(RepositoryHub.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(RepositoryHub.Repo, {:shared, self()})
    end

    :ok
  end
end
