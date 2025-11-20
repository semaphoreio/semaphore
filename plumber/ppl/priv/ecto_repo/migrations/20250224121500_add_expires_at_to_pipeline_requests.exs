defmodule Ppl.EctoRepo.Migrations.AddExpiresAtToPipelineRequests do
  use Ecto.Migration

  def change do
    alter table(:pipeline_requests) do
      add :expires_at, :naive_datetime_usec
    end

    create index(:pipeline_requests, [:created_at, :expires_at], name: :idx_pipeline_requests_created_at_expires_at_not_null, concurrently: true, where: "expires_at IS NOT NULL")
  end
end
