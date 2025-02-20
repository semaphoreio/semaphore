defmodule Guard.Repo.Migrations.AlterRbacRoleTableAddNotNull do
  use Ecto.Migration

  def change do
    alter table("rbac_roles") do
      modify :scope_id, :binary_id, null: false
    end
  end
end
