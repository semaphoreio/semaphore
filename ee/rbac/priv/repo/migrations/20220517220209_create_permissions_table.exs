defmodule Rbac.Repo.Migrations.CreatePermissionsTable do
  use Ecto.Migration

  def change do
    create table(:permissions) do
      add :name, :string, null: false
      add :scope_id, references(:scopes), null: false
      add :description, :string, null: false, default: ""
    end

    create unique_index(:permissions, :name)
  end
end
