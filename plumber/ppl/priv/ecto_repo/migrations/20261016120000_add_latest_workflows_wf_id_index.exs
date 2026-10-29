defmodule Ppl.EctoRepo.Migrations.AddLatestWorkflowsWfIdIndex do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    create_if_not_exists(
      index(
        :latest_workflows,
        [:wf_id],
        name: :index_latest_workflows_on_wf_id,
        concurrently: true
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
        WHERE indexrelid = to_regclass('index_latest_workflows_on_wf_id') AND NOT indisvalid
      ) THEN
        RAISE EXCEPTION 'index_latest_workflows_on_wf_id is INVALID: a concurrent build is still running or an earlier one failed. If none is running, drop it with DROP INDEX CONCURRENTLY index_latest_workflows_on_wf_id and migrate again.';
      END IF;
    END
    $$
    """)
  end

  def down do
    drop_if_exists(
      index(
        :latest_workflows,
        [:wf_id],
        name: :index_latest_workflows_on_wf_id,
        concurrently: true
      )
    )
  end
end
