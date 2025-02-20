defmodule Rbac.Repo.RoleInheritance do
  use Rbac.Repo.Schema
  alias Rbac.Repo.RbacRole

  @primary_key false
  schema "role_inheritance" do
    belongs_to(:inheriting_role, RbacRole, primary_key: true)
    belongs_to(:inherited_role, RbacRole, primary_key: true)
  end
end
