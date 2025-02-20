defmodule Gofer.EctoRepo.Migrations.AddDeploymentTargetToTargetsTable do
  use Ecto.Migration

  def change do
    alter table(:targets) do
      add :deployment_target, :string, null: true
    end
  end
end
