defmodule Ppl.EctoRepo.Migrations.AddIndexesOnStateField do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create index(:pipelines, [:state], concurrently: true)
    create index(:pipeline_sub_inits, [:state], concurrently: true)
    create index(:pipeline_blocks, [:state], concurrently: true)
  end
end
