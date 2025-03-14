defmodule Rbac.Repo.Migrations.MakeGroupMappingNullable do
  use Ecto.Migration

    def change do
      alter table(:idp_group_mapping) do
        remove :group_mapping
        remove :role_mapping

        add :role_mapping, {:array, :map}, null: true, default: []
        add :group_mapping, {:array, :map}, null: true, default: []
      end
  end
end
