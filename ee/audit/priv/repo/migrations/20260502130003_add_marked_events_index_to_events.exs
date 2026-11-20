defmodule Audit.Repo.Migrations.AddMarkedEventsIndexToEvents do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  # Symmetric to the `expires_at IS NULL` marking index: keeps the unmark
  # query (org_id + timestamp >= cutoff, expires_at IS NOT NULL) an index scan.
  # Cheap to maintain since freshly inserted events have expires_at = NULL and
  # never enter this partial index.
  def change do
    create_if_not_exists(
      index(:events, [:org_id, :timestamp],
        name: :events_org_id_timestamp_marked_index,
        concurrently: true,
        where: "expires_at IS NOT NULL"
      )
    )
  end
end
