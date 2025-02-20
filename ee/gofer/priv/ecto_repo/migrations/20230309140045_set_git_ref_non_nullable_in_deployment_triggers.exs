defmodule Gofer.EctoRepo.Migrations.SetGitRefNonNullableInDeploymentTriggers do
  use Ecto.Migration

  def change do
    alter table(:deployment_triggers) do
      modify :git_ref_type, :string, null: false
      modify :git_ref_label, :string, null: false
    end

    create index(:deployment_triggers, [:git_ref_label, :git_ref_type],
             name: :deployment_triggers_by_git_ref
           )

    create index(:deployment_triggers, [:parameter1], name: :deployment_triggers_by_parameter1)
    create index(:deployment_triggers, [:parameter2], name: :deployment_triggers_by_parameter2)
    create index(:deployment_triggers, [:parameter3], name: :deployment_triggers_by_parameter3)
  end
end
