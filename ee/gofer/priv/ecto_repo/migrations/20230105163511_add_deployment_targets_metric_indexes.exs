defmodule Gofer.EctoRepo.Migrations.AddDeploymentTargetsMetricIndexes do
  use Ecto.Migration

  def change do
    create index(:deployments, [:organization_id], name: :organization_deployments)
    create index(:deployments, [:state, :result], name: :deployments_by_state_and_result)
    create index(:deployments, [:updated_at], name: :deployments_by_creation_date)
  end
end
