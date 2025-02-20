defmodule Guard.Repo.Migrations.AlterRbacSubjectRoleBindingsAddIndexes do
  use Ecto.Migration

  def change do
    create index(:subject_role_bindings, [:project_id])
    create index(:subject_role_bindings, [:org_id])
    create index(:subject_role_bindings, [:subject_id])
  end
end
