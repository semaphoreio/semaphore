defmodule Support.Factories.OrgRoleToProjRoleMappings do
  def insert(options \\ []) do
    %Rbac.Repo.OrgRoleToProjRoleMapping{
      org_role_id: get_role_id(options[:org_role_id]),
      proj_role_id: get_role_id(options[:proj_role_id])
    }
    |> Rbac.Repo.insert()
  end

  defp get_role_id(nil) do
    {:ok, rbac_role} = Support.Factories.RbacRole.insert()
    rbac_role.id
  end

  defp get_role_id(role_id), do: role_id
end
