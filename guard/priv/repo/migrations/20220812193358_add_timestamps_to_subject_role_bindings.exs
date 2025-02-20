defmodule Guard.Repo.Migrations.AddTimestampsToSubjectRoleBindings do
  use Ecto.Migration

  def change do
    alter table(:subject_role_bindings) do
      timestamps(default: fragment("now()"))
    end
  end
end
