defmodule RepositoryHub.Repo.Migrations.AddRepositoriesTable do
  @moduledoc false
  use Ecto.Migration

  def change do
    execute("CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";")

    create table(:repositories, primary_key: false) do
      add :id,                   :uuid,        default: fragment("uuid_generate_v4()"), primary_key: true
      add :hook_id,              :string
      add :name,                 :string
      add :owner,                :string
      add :private,              :boolean
      add :provider,             :string
      add :url,                  :string
      add :project_id,           :uuid
      add :enable_commit_status, :boolean,     default: true
      add :pipeline_file,        :string,      default: ".semaphore/semaphore.yml"
      add :commit_status,        :jsonb
      add :whitelist,            :jsonb
      add :integration_type,     :string
      add :connected,            :boolean,     default: true, null: false

      timestamps(inserted_at: :created_at)
    end

  end
end
