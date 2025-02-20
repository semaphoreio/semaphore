defmodule Rbac.Repo.Migrations.CreateRoleAssignment do
  use Ecto.Migration

  def change do
    create table(:role_assignment, primary_key: false) do
      add :user_id, :binary_id, primary_key: true
      add :org_id, :binary_id, primary_key: true
      add :role_id, :binary_id

      timestamps(inserted_at: :created_at, updated_at: :updated_at)
    end

    create index(:role_assignment, [:org_id, :user_id])
    create index(:role_assignment, [:org_id, :role_id])
  end
end
