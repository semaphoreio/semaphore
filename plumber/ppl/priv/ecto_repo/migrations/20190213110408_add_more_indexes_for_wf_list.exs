defmodule Ppl.EctoRepo.Migrations.AddMoreIndexesForWfList do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create index(:pipelines, [:branch_name], concurrently: true)
    create index(:pipeline_requests, [:initial_request], concurrently: true)
  end
end
