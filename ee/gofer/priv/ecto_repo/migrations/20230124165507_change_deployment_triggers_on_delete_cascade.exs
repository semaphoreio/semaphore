defmodule Gofer.EctoRepo.Migrations.ChangeDeploymentTriggersOnDeleteCascade do
  use Ecto.Migration

  def change do
    alter table(:deployment_triggers) do
      modify :deployment_id,
             references(:deployments, type: :uuid, on_delete: :delete_all),
             from: references(:deployments, type: :uuid, on_delete: :nothing),
             null: false

      modify :switch_id,
             references(:switches, type: :uuid, on_delete: :delete_all),
             from: references(:switches, type: :uuid, on_delete: :nothing),
             null: false
    end
  end
end
