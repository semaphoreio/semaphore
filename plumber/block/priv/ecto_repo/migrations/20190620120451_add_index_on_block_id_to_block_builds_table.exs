defmodule Block.EctoRepo.Migrations.AddIndexOnBlockIdToBlockBuildsTable do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create unique_index(:block_builds, [:block_id], concurrently: true)
  end
end
