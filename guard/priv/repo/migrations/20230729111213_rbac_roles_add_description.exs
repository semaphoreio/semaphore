defmodule Guard.Repo.Migrations.RbacRolesAddDescription do
  use Ecto.Migration

  def change do
    alter table(:rbac_roles) do
      add :description, :string, null: true
    end
  end
end
