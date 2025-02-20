defmodule Gofer.EctoRepo.Migrations.AddSwitchTriggersTable do
  use Ecto.Migration

  def change do
    create table(:switch_triggers, primary_key: false) do
      add :switch_id, references(:switches, type: :uuid), null: false
      add :id,             :uuid,   primary_key: true
      add :auto_triggered, :boolean, default: false
      add :triggered_by,   :string
      add :override,       :boolean, default: false
      add :request_token,  :string
      add :processed,      :boolean, default: false
      add :target_names,   {:array, :string}
      add :triggered_at,   :utc_datetime_usec
      add :env_vars_for_target, :map, default: "{}"

      timestamps()
    end

    create unique_index(:switch_triggers, [:request_token], name: :unique_request_token_for_switch_trigger)
  end
end
