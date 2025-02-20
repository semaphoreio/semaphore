defmodule Guard.Repo.Migrations.CreateRolePermissionBindingsTable do
  use Ecto.Migration

  def change do
    create table(:role_permission_bindings, primary_key: false) do
      add :permission_id, references(:permissions), primary_key: true
      add :rbac_role_id, references(:rbac_roles, on_delete: :delete_all), primary_key: true
    end
  end
end
