defmodule RepositoryHub.Repo.Migrations.AddGithubAppInstallationsTable do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:github_app_installations, primary_key: false) do
      add :id,                         :uuid,        default: fragment("uuid_generate_v4()"), primary_key: true
      add :installation_id,            :bigint,      null: false
      add :repositories,               :string,      null: true
      add :suspended_at,               :timestamp,   null: true
      add :permissions_accepted_at,    :timestamp,   null: true

      timestamps(inserted_at: :created_at)
    end
  end
end
