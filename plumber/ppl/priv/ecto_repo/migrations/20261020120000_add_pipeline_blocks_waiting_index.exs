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
