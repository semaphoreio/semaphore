defmodule EphemeralEnvironments.Repo.Migrations.CreateEphemeralSecretDefinitions do
  use Ecto.Migration

  def change do
    create table(:ephemeral_secret_definitions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :environment_type_id, references(:ephemeral_environment_types, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :description, :text
      add :actions_that_can_change_the_secret, {:array, :string}
      add :actions_that_have_access_to_the_secret, {:array, :string}

      timestamps()
    end

    create index(:ephemeral_secret_definitions, [:environment_type_id])
    create unique_index(:ephemeral_secret_definitions, [:environment_type_id, :name])
  end
end
