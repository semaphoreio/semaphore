defmodule Ppl.EctoRepo.Migrations.AddWaitingTerminateRequestedIndexToPipelineBlocks do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  # Serves the terminate-first claim in Ppl.PplBlocks.Model.WaitingStateScheduling.
  # Only waiting blocks with a pending terminate request are indexed, so it stays small.
  def change do
    create_if_not_exists(
      index(
        :pipeline_blocks,
        [:updated_at],
        name: :pipeline_blocks_waiting_terminate_requested_index,
        concurrently: true,
        where: "state = 'waiting' AND in_scheduling = false AND terminate_request IS NOT NULL"
      )
    )
  end
end
