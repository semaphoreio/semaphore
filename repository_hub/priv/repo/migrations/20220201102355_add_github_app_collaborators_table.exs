defmodule RepositoryHub.Repo.Migrations.AddGithubAppCollaboratorsTable do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:github_app_collaborators, primary_key: false) do
      add :id,              :uuid,   default: fragment("uuid_generate_v4()"), primary_key: true
      add :installation_id, :bigint, null: false
      add :c_id,            :bigint, null: false
      add :c_name,          :string, null: false
      add :r_name,          :string, null: false
    end
  end
end
