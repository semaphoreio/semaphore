defmodule EphemeralEnvironments.Repo.Migrations.CreateInstanceStateChanges do
  use Ecto.Migration

  def change do
    create table(:instance_state_changes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :instance_id, references(:ephemeral_environment_instances, type: :binary_id, on_delete: :delete_all), null: false
      add :prev_state, :string
      add :next_state, :string
      add :state_change_action_id, references(:state_change_actions, type: :binary_id, on_delete: :delete_all), null: false
      add :result, :string, null: false
      add :trigger_type, :string, null: false
      add :trigger_id, :binary_id, null: false
      add :execution_ppl_id, :binary_id
      add :execution_id, :binary_id

      timestamps()
    end

    create index(:instance_state_changes, [:instance_id])
  end
end
