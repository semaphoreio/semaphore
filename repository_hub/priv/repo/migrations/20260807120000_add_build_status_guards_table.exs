defmodule RepositoryHub.Repo.Migrations.AddBuildStatusGuardsTable do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:build_status_guards, primary_key: false) do
      add(:repository_id, :uuid, null: false, primary_key: true)
      add(:commit_sha, :text, null: false, primary_key: true)
      add(:context, :text, null: false, primary_key: true)
      add(:source_id, :text, null: false, primary_key: true)
      add(:last_state, :string, null: true)
      add(:claimed_at, :timestamptz, null: true)
      add(:updated_at, :timestamptz, null: false)
    end

    create(index(:build_status_guards, [:updated_at]))
  end
end
