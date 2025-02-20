defmodule Block.EctoRepo.Migrations.AddStateIndexToBlocksTable do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create index(:blocks, [:state], concurrently: true)
  end
end
