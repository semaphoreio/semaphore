defmodule EphemeralEnvironments.Repo.Migrations.AddUniqueConstraintToEnvironmentTypeName do
  use Ecto.Migration

  def change do
    create unique_index(:ephemeral_environment_types, [:org_id, :name],
             name: :ephemeral_environment_types_org_id_name_index
           )
  end
end
