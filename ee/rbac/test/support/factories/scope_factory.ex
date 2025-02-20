defmodule Support.Factories.Scope do
  alias Rbac.Repo.Scope

  def insert(scope_name \\ nil) do
    scope_name =
      if scope_name == nil do
        for _ <- 1..10, into: "", do: <<Enum.random(~c"abcdefghijk")>>
      else
        scope_name
      end

    %Scope{scope_name: scope_name} |> Rbac.Repo.insert()
  end
end
