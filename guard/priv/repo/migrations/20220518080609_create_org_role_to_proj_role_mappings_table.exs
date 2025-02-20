defmodule Guard.Repo.Migrations.CreateOrgRoleToProjRoleMappingsTable do
  use Ecto.Migration

  def change do
    create table(:org_role_to_proj_role_mappings, primary_key: false) do
      add :org_role_id, references(:rbac_roles, on_delete: :delete_all), primary_key: true
      add :proj_role_id, references(:rbac_roles, on_delete: :delete_all), primary_key: true
    end
  end
end
