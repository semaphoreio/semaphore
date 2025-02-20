defmodule Gofer.EctoRepo.Migrations.AddDeploymentTriggersTable do
  use Ecto.Migration

  def change do
    create table(:deployment_triggers, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :deployment_id, references(:deployments, type: :uuid), null: false
      add :switch_id, references(:switches, type: :uuid), null: false
      add :triggered_at, :utc_datetime_usec, null: false
      add :triggered_by, :string, null: false

      add :switch_trigger_id, :string, null: false
      add :target_name, :string, null: false
      add :request_token, :string, null: false
      add :switch_trigger_params, :map

      add :scheduled_at, :utc_datetime_usec
      add :pipeline_id, :string

      add :state, :string, null: false
      add :result, :string, null: true
      add :reason, :text, null: true

      timestamps()
    end

    create unique_index(:deployment_triggers, [:switch_trigger_id, :target_name],
             name: :unique_deployment_trigger_per_target_trigger
           )

    create unique_index(:deployment_triggers, [:request_token],
             name: :unique_deployment_trigger_per_request_token
           )

    create index(:deployment_triggers, [:deployment_id], name: :deployment_trigger_instances)
    create index(:deployment_triggers, [:switch_id], name: :switch_deployment_triggers)

    create index(:deployment_triggers, [:deployment_id, :triggered_at],
             name: :deployment_triggers_per_deployment_and_timestamp
           )

    create index(:deployment_triggers, [:state, :updated_at],
             name: :deployment_triggers_per_state_and_updated_at
           )
  end
end
