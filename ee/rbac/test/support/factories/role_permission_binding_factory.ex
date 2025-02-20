defmodule Support.Factories.RolePermissionBinding do
  alias Rbac.Repo.RolePermissionBinding

  def insert(options \\ []) do
    %RolePermissionBinding{
      rbac_role_id: get_role_id(options[:rbac_role_id]),
      permission_id: get_permission_id(options[:permission_id])
    }
    |> Rbac.Repo.insert(
      on_conflict: {:replace, [:rbac_role_id, :permission_id]},
      conflict_target: [:rbac_role_id, :permission_id]
    )
  end

  defp get_role_id(nil) do
    {:ok, rbac_role} = Support.Factories.RbacRole.insert()
    rbac_role.id
  end

  defp get_role_id(role_id), do: role_id

  defp get_permission_id(nil) do
    {:ok, permission} = Support.Factories.Permission.insert()
    permission.id
  end

  defp get_permission_id(permission_id), do: permission_id
end
