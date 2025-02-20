defmodule Gofer.EctoRepo.Migrations.AddTargetTriggersTable do
  use Ecto.Migration

  def change do
    create table(:target_triggers) do
      add :switch_id, references(:switches, type: :uuid), null: false
      add :switch_trigger_id, references(:switch_triggers, type: :uuid), null: false
      add :target_name,            :string
      add :schedule_request_token, :string
      add :scheduled_ppl_id,       :string
      add :scheduled_at,           :utc_datetime_usec
      add :error_response,         :text
      add :processed,              :boolean, default: false
      add :processing_result,      :string

      timestamps()
    end

    create unique_index(:target_triggers, [:switch_trigger_id, :target_name], name: :one_target_trigger_per_tartget_per_switch_trigger)
  end
end
