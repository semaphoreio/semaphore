defmodule Ppl.EctoRepo.Migrations.AddExpiresAtToPipelineRequests do
  use Ecto.Migration

  def change do
    alter table(:pipeline_requests) do
      add_if_not_exists :expires_at, :naive_datetime_usec
    end
  end
end
