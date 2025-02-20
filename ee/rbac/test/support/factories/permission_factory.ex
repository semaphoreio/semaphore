defmodule Support.Factories.Permission do
  alias Rbac.Repo.Permission

  def insert(options \\ []) do
    %Permission{
      name: get_name(options[:name]),
      scope_id: get_scope_id(options[:scope_id])
    }
    |> Rbac.Repo.insert(on_conflict: :nothing, conflict_target: :name)
  end

  defp get_name(nil), do: for(_ <- 1..10, into: "", do: <<Enum.random(~c"abcdefghijk")>>)
  defp get_name(name), do: name

  defp get_scope_id(nil) do
    {:ok, scope} = Support.Factories.Scope.insert()
    Map.get(scope, :id)
  end

  defp get_scope_id(scope_id), do: scope_id
end
