defmodule Guard.Repo.Migrations.AddNeededIndexes do
  use Ecto.Migration

  def change do
    create index(:role_permission_bindings, [:rbac_role_id])
    create index(:org_role_to_proj_role_mappings, [:org_role_id])
    create index(:role_inheritance, [:inheriting_role_id])
  end
end
