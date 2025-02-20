defmodule Guard.Repo.Migrations.SetDefaultForDescriptionInRbacRoles do
  use Ecto.Migration

  def change do
    alter table(:rbac_roles) do
      modify(:description, :string, default: "")
    end
  end
end
