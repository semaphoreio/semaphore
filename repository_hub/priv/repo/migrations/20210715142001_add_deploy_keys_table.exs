defmodule RepositoryHub.Repo.Migrations.AddDeployKeysTable do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:deploy_keys, primary_key: false) do
      add :id,          :uuid,        default: fragment("uuid_generate_v4()"), primary_key: true
      add :private_key, :text
      add :public_key,  :text
      add :project_id,  :uuid
      add :deployed,    :boolean
      add :remote_id,   :integer

      timestamps(inserted_at: :created_at)
    end
  end
end
