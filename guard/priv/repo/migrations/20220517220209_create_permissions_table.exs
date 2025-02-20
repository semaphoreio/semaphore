defmodule Guard.Repo.Migrations.CreatePermissionsTable do
  use Ecto.Migration

  def change do
    create table(:permissions) do
      add :name, :string, null: false
      add :scope_id, references(:scopes), null: false
    end

    create unique_index(:permissions, :name)
  end
end
