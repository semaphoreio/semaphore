defmodule Guard.FrontRepo.Migrations.CreateMembers do
  use Ecto.Migration

  def change do
    create table(:members, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :github_uid, :string
      add :repo_host, :string
      add :organization_id, :binary_id

      timestamps(inserted_at: :created_at, updated_at: :updated_at)
    end
  end
end
