defmodule Gofer.EctoRepo.Migrations.AddDeploymentsTable do
  use Ecto.Migration

  def change do
    create table(:deployments, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :name, :string, null: false
      add :description, :text, null: false, default: ""
      add :url, :text, null: false, default: ""

      add :state, :string, null: false
      add :result, :string, null: false
      add :unique_token, :string, null: false

      add :organization_id, :string, null: false
      add :project_id, :string, null: false
      add :created_by, :string, null: false
      add :updated_by, :string, null: false

      add :secret_id, :string, null: true
      add :secret_name, :string, null: true

      add :encrypted_secret, :map
      add :subject_rules, :map
      add :object_rules, :map

      timestamps()
    end

    create unique_index(:deployments, [:project_id, :name], name: :unique_deployments_per_project)
    create unique_index(:deployments, [:unique_token], name: :unique_deployments_per_unique_token)
    create index(:deployments, [:project_id], name: :project_deployments)
  end
end
