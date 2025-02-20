defmodule Ppl.EctoRepo.Migrations.AddPreFlightChecksToPipelineRequestsTable do
  use Ecto.Migration

  def change do
    alter table(:pipeline_requests) do
      add :pre_flight_checks, :map
    end
  end
end
