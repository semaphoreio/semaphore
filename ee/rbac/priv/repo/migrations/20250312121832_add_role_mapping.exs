defmodule Rbac.Repo.Migrations.AddRoleMapping do
  use Ecto.Migration

  def change do
    alter table(:idp_group_mapping) do
      add :role_mapping, :map, null: true, default: %{}
    end
  end
end
