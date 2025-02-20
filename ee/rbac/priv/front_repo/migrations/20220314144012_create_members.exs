defmodule Rbac.FrontRepo.Migrations.CreateMembers do
  use Ecto.Migration

  def change do
    create table(:members, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :github_uid, :string
      add :repo_host, :string
      add :organization_id, :binary_id
      add :github_username, :string
      add :invite_email, :string


      timestamps(inserted_at: :created_at, updated_at: :updated_at)
    end

    create unique_index(:members, [:github_uid, :organization_id, :repo_host], name: :members_organization_repo_host_uid_index)
  end
end
