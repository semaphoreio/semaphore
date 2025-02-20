defmodule Rbac.Repo.Migrations.CreateCollaboratorTable do
  use Ecto.Migration

  def change do
    create table(:collaborators, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :project_id, :binary_id
      add :github_username, :string
      add :github_uid, :string
      add :github_email, :string
      add :admin, :boolean, default: false, null: false
      add :push, :boolean, default: false, null: false
      add :pull, :boolean, default: false, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:collaborators, [:github_uid])
    create index(:collaborators, [:project_id])
    create unique_index(:collaborators, [:project_id, :github_uid], name: :unique_githubber_in_project)

  end
end
