defmodule Guard.Repo.Migrations.AddRbacRoleEditableField do
  use Ecto.Migration

  def change do
    alter table(:rbac_roles) do
      add :editable, :boolean, default: false, null: false
    end
  end
end
