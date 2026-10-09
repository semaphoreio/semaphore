defmodule Ppl.EctoRepo.Migrations.AddWaitingTerminateRequestedIndexToPipelineBlocks do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  @index "pipeline_blocks_waiting_terminate_requested_index"

  # Serves the terminate-first claim in Ppl.PplBlocks.Model.WaitingStateScheduling.
  # Only waiting blocks with a pending terminate request are indexed, so it stays small.
  def up do
    # A failed CREATE INDEX CONCURRENTLY leaves an INVALID index behind, and
    # IF NOT EXISTS would then skip the build. Drop such a leftover first.
    if invalid_index?() do
      execute("DROP INDEX CONCURRENTLY IF EXISTS #{@index}")
    end

    execute("""
    CREATE INDEX CONCURRENTLY IF NOT EXISTS #{@index}
    ON pipeline_blocks (updated_at)
    WHERE state = 'waiting' AND in_scheduling = false AND terminate_request IS NOT NULL
    """)
  end

  def down do
    execute("DROP INDEX CONCURRENTLY IF EXISTS #{@index}")
  end

  defp invalid_index? do
    %{rows: rows} =
      repo().query!(
        """
        SELECT 1
        FROM pg_index i
        JOIN pg_class c ON c.oid = i.indexrelid
        WHERE c.relname = $1 AND NOT i.indisvalid
        """,
        [@index]
      )

    rows != []
  end
end
