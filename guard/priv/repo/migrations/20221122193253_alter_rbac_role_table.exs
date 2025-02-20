defmodule Guard.Repo.Migrations.AlterRbacRoleTable do
  use Ecto.Migration

  def change do
    alter table("rbac_roles") do
      modify :inserted_at, :naive_datetime, default: fragment("now()")
      modify :updated_at, :naive_datetime, default: fragment("now()")
    end
  end
end
