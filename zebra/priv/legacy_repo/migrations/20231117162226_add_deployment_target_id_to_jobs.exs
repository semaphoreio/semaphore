defmodule Zebra.LegacyRepo.Migrations.AddDeploymentTargetIdToJobs do
  use Ecto.Migration

  def change do
    alter table(:jobs) do
      add :deployment_target_id, :binary_id
    end
  end
end
