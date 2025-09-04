defmodule EphemeralEnvironments.Repo.Migrations.CreateEphemeralSecretInstances do
  use Ecto.Migration

  def change do
    create table(:ephemeral_secret_instances, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :instance_id, references(:ephemeral_environment_instances, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :value, :text, null: false

      timestamps()
    end

    create index(:ephemeral_secret_instances, [:instance_id])
    create unique_index(:ephemeral_secret_instances, [:instance_id, :name])
  end
end
