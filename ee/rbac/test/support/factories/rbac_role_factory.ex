defmodule Support.Factories.RbacRole do
  alias Rbac.Repo.RbacRole
  alias Ecto.UUID

  def insert(options \\ []) do
    %RbacRole{
      name: get_name(options[:name]),
      scope_id: get_scope_id(options[:scope_id]),
      org_id: get_org_id(options[:org_id]),
      description: get_name(options[:description])
    }
    |> Rbac.Repo.insert(on_conflict: :replace_all, conflict_target: [:name, :org_id, :scope_id])
  end

  defp get_org_id(nil), do: UUID.generate()
  defp get_org_id(org_id), do: org_id

  # Generates random 10 letter string
  defp get_name(nil), do: for(_ <- 1..10, into: "", do: <<Enum.random(~c"abcdefghijk")>>)
  defp get_name(name), do: name

  defp get_scope_id(nil) do
    {:ok, scope} = Support.Factories.Scope.insert()
    scope.id
  end

  defp get_scope_id(scope_id), do: scope_id
end
