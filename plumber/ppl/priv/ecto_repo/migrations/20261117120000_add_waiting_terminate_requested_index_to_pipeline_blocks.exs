defmodule Ppl.EctoRepo.Migrations.AddWaitingTerminateRequestedIndexToPipelineBlocks do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create_if_not_exists index(
      :pipeline_blocks,
      [:updated_at],
      name: :pipeline_blocks_waiting_terminate_requested_index,
      concurrently: true,
      where: "state = 'waiting' AND in_scheduling = false AND terminate_request IS NOT NULL"
    )
  end
end
