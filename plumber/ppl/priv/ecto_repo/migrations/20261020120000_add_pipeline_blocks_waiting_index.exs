defmodule Ppl.EctoRepo.Migrations.AddPipelineBlocksWaitingIndex do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    create_if_not_exists(
      index(
        :pipeline_blocks,
        [:id],
        name: :index_pipeline_blocks_on_waiting,
        concurrently: true,
        where: "state = 'waiting'"
      )
    )

    # IF NOT EXISTS matches on the name only, so an INVALID index left by a
    # failed concurrent build would be skipped and this migration recorded as
    # done. Fail instead, so the broken index cannot go unnoticed.
    execute("""
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1 FROM pg_index
        WHERE indexrelid = to_regclass('index_pipeline_blocks_on_waiting') AND NOT indisvalid
      ) THEN
        RAISE EXCEPTION 'index_pipeline_blocks_on_waiting is INVALID: a concurrent build is still running or an earlier one failed. If none is running, drop it with DROP INDEX CONCURRENTLY index_pipeline_blocks_on_waiting and migrate again.';
      END IF;
    END
    $$
    """)
  end

  def down do
    drop_if_exists(
      index(
        :pipeline_blocks,
        [:id],
        name: :index_pipeline_blocks_on_waiting,
        concurrently: true,
        where: "state = 'waiting'"
      )
    )
  end
end
