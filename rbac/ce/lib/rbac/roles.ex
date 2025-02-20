defmodule Rbac.Roles do
  alias InternalApi.RBAC

  def list do
    [
      __MODULE__.Owner.role(),
      __MODULE__.Admin.role(),
      __MODULE__.Member.role()
    ]
  end

  def find_by_id(id) do
    list()
    |> Enum.find(&(&1.id == id))
  end

  def find_by_name(name) do
    list()
    |> Enum.find(&(&1.name == name))
  end

  def build_grpc_roles do
    all_roles = list()
    all_permissions = Rbac.Permissions.list()

    permissions_by_name =
      Enum.reduce(all_permissions, %{}, fn permission, acc ->
        Map.put(acc, permission.name, permission)
      end)

    all_roles
    |> Stream.map(&assign_permissions(&1, permissions_by_name))
    |> Enum.map(&construct_grpc_role(&1))
  end

  defp assign_permissions(role, permissions_by_name) do
    %{
      role
      | permissions: Enum.map(role.permissions, &Map.get(permissions_by_name, &1))
    }
  end

  def construct_grpc_role(role, assign_permissions: true) do
    all_permissions = Rbac.Permissions.list()

    permissions_by_name =
      Enum.reduce(all_permissions, %{}, fn permission, acc ->
        Map.put(acc, permission.name, permission)
      end)

    assign_permissions(role, permissions_by_name)
    |> construct_grpc_role()
  end

  defp construct_grpc_role(nil), do: nil

  defp construct_grpc_role(role) do
    %RBAC.Role{
      id: role.id,
      name: role.name,
      description: role.description,
      permissions: Enum.map(role.permissions, & &1.name),
      rbac_permissions: Enum.map(role.permissions, &Rbac.Permissions.construct_grpc_permission/1),
      scope: RBAC.Scope.value(:SCOPE_ORG),
      readonly: true
    }
  end
end
