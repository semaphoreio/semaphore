defmodule Rbac.Repo.RolePermissionBinding do
  use Rbac.Repo.Schema
  alias Rbac.Repo.{RbacRole, Permission}

  @primary_key false
  schema "role_permission_bindings" do
    belongs_to(:rbac_role, RbacRole, primary_key: true)
    belongs_to(:permission, Permission, primary_key: true)
  end
end
