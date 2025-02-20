defmodule Ppl.EctoRepo.Migrations.AddQueueIdIndexToPipelines do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create index(:pipelines, [:queue_id],
                 where: "queue_id IS NOT NULL",
                 concurrently: true)
  end
end
