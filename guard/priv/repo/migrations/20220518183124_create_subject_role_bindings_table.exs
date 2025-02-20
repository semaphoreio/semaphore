defmodule Guard.Repo.Migrations.CreateSubjectRoleBindingsTable do
  use Ecto.Migration

  def change do
   execute(
    "CREATE TYPE role_binding_scope AS ENUM ('github', 'bitbucket', 'gitlab', 'manually_assigned')",
    "DROP TYPE role_binding_scope")

   create table(:subject_role_bindings) do
      add :role_id, references(:rbac_roles), null: false
      add :org_id, :binary_id
      add :project_id, :binary_id
      add :subject_id, references(:subjects), null: false
      add :binding_source, :role_binding_scope, null: false
    end

    create unique_index(:subject_role_bindings, [:subject_id, :org_id, :binding_source], where: "project_id IS NULL")
    create unique_index(:subject_role_bindings, [:subject_id, :org_id, :project_id, :binding_source], where: "project_id IS NOT NULL")
  end
end
