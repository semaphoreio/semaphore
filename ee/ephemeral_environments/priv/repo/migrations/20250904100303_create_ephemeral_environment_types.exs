defmodule EphemeralEnvironments.Repo.Migrations.CreateEphemeralEnvironmentTypes do
  use Ecto.Migration
  
  def change do
    create table(:ephemeral_environment_types, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :org_id, :binary_id, null: false
      add :name, :string, null: false
      add :description, :string
      add :created_by, :binary_id, null: false
      add :last_modified_by, :binary_id, null: false
      add :state, :string, null: false
      add :max_number_of_instances, :integer
      timestamps()
    end
    create index(:ephemeral_environment_types, [:org_id])
  end
end