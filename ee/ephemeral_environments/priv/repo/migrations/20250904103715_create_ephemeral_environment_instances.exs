defmodule EphemeralEnvironments.Repo.Migrations.CreateEphemeralEnvironmentInstances do
  use Ecto.Migration

  def change do
    create table(:ephemeral_environment_instances, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :environment_type_id, references(:ephemeral_environment_types, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :state, :string, null: false

      timestamps()
    end

    create index(:ephemeral_environment_instances, [:environment_type_id])
  end
end
