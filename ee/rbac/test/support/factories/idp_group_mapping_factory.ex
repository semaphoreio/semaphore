defmodule Support.Factories.IdpGroupMapping do
  alias Rbac.Repo.IdpGroupMapping
  alias Ecto.UUID

  @doc """
    Expected arg options:
    - organization_id
    - default_role_id
    - role_mapping      (map)
    - group_mapping     (map)

    All of these parameters are optional. If role id are not given, new roles will be created and used.
    If org_id is not given, new one will be generated
  """
  def insert(options \\ []) do
    %IdpGroupMapping{
      organization_id: get_id(options[:organization_id]),
      default_role_id: get_role_id(options[:default_role_id]),
      role_mapping: get_mappings(options[:role_mapping]),
      group_mapping: get_mappings(options[:group_mapping])
    }
    |> Rbac.Repo.insert(on_conflict: :replace_all, conflict_target: :id)
  end

  defp get_id(nil), do: UUID.generate()
  defp get_id(id), do: id

  defp get_role_id(nil), do: Support.Factories.RbacRole.insert() |> elem(1) |> Map.get(:id)
  defp get_role_id(id), do: id

  defp get_mappings(nil), do: []
  defp get_mappings(mappings), do: mappings
end
