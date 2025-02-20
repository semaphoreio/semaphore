defmodule Ppl.EctoRepo.Migrations.AddIndexOnInsertedAtOnPipelineRequestsTable do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create index(:pipeline_requests, [:inserted_at], concurrently: true)
  end
end
