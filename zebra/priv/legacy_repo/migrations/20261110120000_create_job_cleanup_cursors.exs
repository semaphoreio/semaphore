defmodule Zebra.LegacyRepo.Migrations.CreateJobCleanupCursors do
  use Ecto.Migration

  # Test/dev mirror of the github_hooks migration that owns this table in production.
  def change do
    create table(:job_cleanup_cursors, primary_key: false) do
      add :name, :text, primary_key: true
      add :finished_at, :naive_datetime_usec, null: false
      add :job_id, :binary_id, null: false
      add :updated_at, :utc_datetime, null: false
    end
  end
end
