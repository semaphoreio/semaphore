defmodule Rbac.Repo.Migrations.CreateProjectAssignment do
  use Ecto.Migration

  def change do
    create table(:project_assignment, primary_key: false) do
      add :project_id, :binary_id, primary_key: true
      add :user_id, :binary_id, primary_key: true
      add :org_id, :binary_id, primary_key: true

      timestamps(inserted_at: :created_at, updated_at: :updated_at)
    end

    create index(:project_assignment, [:org_id, :project_id])
    create index(:project_assignment, [:org_id, :user_id])
  end
end
