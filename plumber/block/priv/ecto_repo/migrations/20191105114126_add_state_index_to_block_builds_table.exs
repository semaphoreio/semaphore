defmodule Block.EctoRepo.Migrations.AddStateIndexToBlockBuildsTable do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create index(:block_builds, [:state], concurrently: true)
  end
end
