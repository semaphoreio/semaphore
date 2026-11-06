defmodule Ppl.EctoRepo.Migrations.AddPipelineTracesDoneAtIndex do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  # List pipelines with done_before/done_after: lets the planner start from the
  # done window instead of reading every done pipeline of the project.
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
