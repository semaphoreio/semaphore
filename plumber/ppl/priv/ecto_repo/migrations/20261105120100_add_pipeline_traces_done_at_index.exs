defmodule Ppl.EctoRepo.Migrations.AddPipelineTracesDoneAtIndex do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  # List pipelines with done_before/done_after: lets the planner start from the
  # done window instead of reading every done pipeline of the project.
  #
  # An interrupted concurrent build leaves an INVALID index behind, and
  # create_if_not_exists then skips it by name. Check
  #   SELECT indisvalid FROM pg_index
  #   WHERE indexrelid = 'pipeline_traces_done_at_index'::regclass;
  # If it is false, DROP INDEX CONCURRENTLY pipeline_traces_done_at_index and
  # recreate it by hand with the same CREATE INDEX CONCURRENTLY statement.
  # Running this migration again is a no-op once its version is recorded.
  def change do
    create_if_not_exists index(
      :pipeline_traces,
      [:done_at],
      name: :pipeline_traces_done_at_index,
      concurrently: true,
      where: "done_at IS NOT NULL"
    )
  end
end
