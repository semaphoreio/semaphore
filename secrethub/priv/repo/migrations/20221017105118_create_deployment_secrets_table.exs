defmodule Secrethub.Repo.Migrations.CreateDeploymentSecretsTable do
  use Ecto.Migration

  def change do
    create table(:deployment_target_secrets, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :org_id, :binary_id, null: false
      add :dt_id, :binary_id, null: false
      add :name, :string, null: false

      add :created_by, :string, null: false
      add :updated_by, :string, null: false
      add :used_at, :utc_datetime

      add :content, :map
      add :used_by, :map

      timestamps()
    end

    create index(:deployment_target_secrets, [:name])
    create index(:deployment_target_secrets, [:org_id])
    create unique_index(:deployment_target_secrets, [:dt_id])
    create unique_index(:deployment_target_secrets, [:name, :org_id])
  end
end
