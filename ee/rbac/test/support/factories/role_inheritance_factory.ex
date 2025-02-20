defmodule Support.Factories.RoleInheritance do
  def insert(options \\ []) do
    %Rbac.Repo.RoleInheritance{
      inheriting_role_id: get_role_id(options[:inheriting_role_id]),
      inherited_role_id: get_role_id(options[:inherited_role_id])
    }
    |> Rbac.Repo.insert()
  end

  defp get_role_id(nil) do
    {:ok, rbac_role} = Support.Factories.RbacRole.insert()
    rbac_role.id
  end

  defp get_role_id(role_id), do: role_id
end
