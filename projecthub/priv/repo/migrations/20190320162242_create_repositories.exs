defmodule Projecthub.Repo.Migrations.CreateRepositories do
  use Ecto.Migration

  def change do
    create table(:repositories) do
      add :hook_id, :string
      add :name, :string
      add :owner, :string
      add :private, :boolean
      add :provider, :string
      add :url, :string
      add :created_at, :utc_datetime
      add :updated_at, :utc_datetime
      add :project_id, :binary_id
      add :enable_commit_status, :boolean, default: true
    end

    create index(:repositories, [:project_id], name: "index_repositories_on_project_id")
  end
end
