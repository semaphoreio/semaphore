defmodule BranchHub.Repo.Migrations.AddBranchesTable do
  use Ecto.Migration

  def change do
    execute("CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";")

    create table(:branches, primary_key: false) do
      add :id,                     :uuid,       default: fragment("uuid_generate_v4()"), primary_key: true
      add :name,                   :string
      add :display_name,           :string
      add :project_id,             :uuid
      add :pull_request_number,    :integer
      add :pull_request_name,      :string
      add :pull_request_mergeable, :boolean
      add :ref_type,               :string
      add :archived_at,            :timestamp
      add :used_at,                :timestamp

      timestamps(inserted_at: :created_at)
    end

  end
end
