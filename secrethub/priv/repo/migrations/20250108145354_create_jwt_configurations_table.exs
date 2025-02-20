defmodule Secrethub.Repo.Migrations.CreateJWTConfiguration do
  use Ecto.Migration

  def up do
    create table(:jwt_configurations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :org_id, :binary_id, null: false
      add :project_id, :binary_id, null: true
      add :claims, {:array, :map}, null: false, default: []
      add :is_active, :boolean, null: false, default: true

      timestamps()
    end

    create unique_index(:jwt_configurations, [:org_id, :project_id])
  end

  def down do
    drop table(:jwt_configurations)
  end
end
