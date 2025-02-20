defmodule Rbac.Repo.Migrations.CreateRbacRolesTable do
  use Ecto.Migration

  def change do
    create table(:rbac_roles) do
      add :name, :string, null: false
      add :description, :string, default: ""
      add :org_id, :binary_id
      add :scope_id, references(:scopes)
      add :editable, :boolean, default: false, null: false
      timestamps(type: :naive_datetime, default: fragment("now()"))
    end

    create unique_index(:rbac_roles, [:name, :org_id, :scope_id])
  end
end
