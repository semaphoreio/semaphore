defmodule Guard.Repo.Migrations.AddGroupMappingTable do
  use Ecto.Migration

  def change do
    create table(:idp_group_mapping) do
      add :organization_id, :uuid, null: false
      add :group_mapping, :map, null: false
      add :default_role_id, :uuid, null: false

      timestamps()
    end

    create index(:idp_group_mapping, [:organization_id])
  end
end
