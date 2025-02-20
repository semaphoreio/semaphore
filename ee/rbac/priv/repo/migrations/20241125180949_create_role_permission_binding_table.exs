defmodule Rbac.Repo.Migrations.CreateRolePermissionBindingTable do
  use Ecto.Migration

  def change do
    create table(:role_permission_bindings, primary_key: false) do
      add :permission_id, references(:permissions), primary_key: true
      add :rbac_role_id, references(:rbac_roles, on_delete: :delete_all), primary_key: true
    end

    create index(:role_permission_bindings, [:rbac_role_id])
    create index(:org_role_to_proj_role_mappings, [:org_role_id])
    create index(:role_inheritance, [:inheriting_role_id])
  end
end
