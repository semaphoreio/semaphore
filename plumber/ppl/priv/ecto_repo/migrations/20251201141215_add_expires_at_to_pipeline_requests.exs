defmodule Ppl.EctoRepo.Migrations.AddExpiresAtToPipelineRequests do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    alter table(:pipeline_requests) do
      add :expires_at, :naive_datetime_usec
    end

    create index(:pipeline_requests, [:inserted_at, :expires_at], name: :idx_pipeline_requests_created_at_expires_at_not_null, concurrently: true, where: "expires_at IS NOT NULL")

    create index(:pipeline_requests, [:expires_at], name: :idx_pipeline_requests_expires_at_for_deletion, concurrently: true, where: "expires_at IS NOT NULL")
  end
end
