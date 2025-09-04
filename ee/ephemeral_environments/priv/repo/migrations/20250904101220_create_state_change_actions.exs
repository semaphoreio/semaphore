defmodule EphemeralEnvironments.Repo.Migrations.CreateStateChangeActions do
  use Ecto.Migration

  def change do
    create table(:state_change_actions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :environment_type_id, references(:ephemeral_environment_types, type: :binary_id, on_delete: :delete_all), null: false
      add :state_change_type, :string, null: false
      add :project_id, :binary_id
      add :branch, :string
      add :pipeline_yaml_name, :string, null: false

      timestamps()
    end

    create index(:state_change_actions, [:environment_type_id])
    create index(:state_change_actions, [:state_change_type])
    create index(:state_change_actions, [:project_id])
  end
end
