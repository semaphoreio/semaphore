defmodule Guard.Repo.Migrations.CreateRbacRolesTable do
  use Ecto.Migration

  def change do
    create table(:rbac_roles) do
      add :name, :string, null: false
      add :org_id, :binary_id
      add :scope_id, references(:scopes)

      timestamps()
    end

    create unique_index(:rbac_roles, [:name, :org_id, :scope_id])
  end
end
