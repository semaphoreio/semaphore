defmodule Audit.Repo.Migrations.AddOrgIdStreamedTimestampIndexToEvents do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    create_if_not_exists(index(:events, [:org_id, :streamed, :timestamp], concurrently: true))

    # IF NOT EXISTS matches on the name only, so an INVALID index left by a
    # failed concurrent build would otherwise be skipped silently.
    execute("""
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1 FROM pg_index
        WHERE indexrelid = to_regclass('events_org_id_streamed_timestamp_index') AND NOT indisvalid
      ) THEN
        RAISE EXCEPTION 'events_org_id_streamed_timestamp_index is INVALID: a concurrent build is still running or an earlier one failed. If none is running, drop it with DROP INDEX CONCURRENTLY events_org_id_streamed_timestamp_index and migrate again.';
      END IF;
    END
    $$
    """)
  end

  def down do
    drop_if_exists(index(:events, [:org_id, :streamed, :timestamp], concurrently: true))
  end
end
