defmodule Ppl.EctoRepo.Migrations.AddInsertedAtIndexToPipelines do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create index(:pipelines, [:inserted_at], concurrently: true)
  end
end
