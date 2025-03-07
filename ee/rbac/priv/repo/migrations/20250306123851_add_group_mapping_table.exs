defmodule Rbac.Repo.Migrations.AddGroupMappingTable do
  use Ecto.Migration

  def change do
    create table(:idp_group_mapping) do
      add :organization_id, :uuid, null: false
      add :group_mappings, :map, null: false

      timestamps()
    end

    create index(:idp_group_mapping, [:organization_id])
  end
end
