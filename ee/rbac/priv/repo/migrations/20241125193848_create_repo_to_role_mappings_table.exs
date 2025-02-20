defmodule Rbac.Repo.Migrations.CreateRepoToRoleMappingsTable do
  use Ecto.Migration

  def change do
    create table(:repo_to_role_mappings, primary_key: false) do
      add :org_id, :binary_id, primary_key: true
      add :admin_access_role_id, references(:rbac_roles), null: false
      add :push_access_role_id, references(:rbac_roles), null: false
      add :pull_access_role_id, references(:rbac_roles), null: false
    end
  end
end
