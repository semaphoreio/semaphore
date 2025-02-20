defmodule Guard.Repo.Migrations.CreateCollaborators do
  use Ecto.Migration

  def change do
    create table(:collaborators, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :project_id, :binary_id
      add :github_username, :string
      add :github_uid, :string

      timestamps(type: :utc_datetime_usec)
    end

    create index(:collaborators, [:github_uid])
    create index(:collaborators, [:project_id])
  end
end
