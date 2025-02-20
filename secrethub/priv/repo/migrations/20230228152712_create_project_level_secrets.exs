defmodule Secrethub.Repo.Migrations.CreateProjectLevelSecrets do
  use Ecto.Migration

  def change do
      create table(:project_level_secrets, primary_key: false) do
        add :id, :binary_id, primary_key: true
        add :org_id, :binary_id, null: false
        add :project_id, :binary_id, null: false
        add :name, :string, null: false

        add :created_by, :string, null: false
        add :updated_by, :string, null: false
        add :used_at, :utc_datetime

        add :content, :map
        add :used_by, :map

        timestamps()
      end

      create index(:project_level_secrets, [:org_id, :name])
      create index(:project_level_secrets, [:project_id])
      create unique_index(:project_level_secrets, [:project_id, :name], name: :unique_names_in_project)

  end
end
