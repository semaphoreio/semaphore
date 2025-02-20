defmodule Ppl.EctoRepo.Migrations.AddInsertedAtAndIdIndexToPipelinesTable do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create index(:pipelines, ["inserted_at DESC NULLS LAST", "id DESC NULLS LAST"],
                  concurrently: true)
  end
end
