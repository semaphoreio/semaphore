defmodule Projecthub.Repo.Migrations.CreateDeployKeys do
  use Ecto.Migration

  def change do
    create table(:deploy_keys) do
      add :private_key, :text
      add :public_key, :text
      add :deployed, :boolean, default: false
      add :remote_id, :integer
      add :project_id, :binary_id
      add :created_at, :utc_datetime
      add :updated_at, :utc_datetime
    end

    create index(:deploy_keys, [:project_id], name: "index_deploy_keys_on_project_id")
  end
end
