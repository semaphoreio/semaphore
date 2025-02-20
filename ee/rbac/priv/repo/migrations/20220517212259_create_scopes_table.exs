defmodule Rbac.Repo.Migrations.CreateScopeTable do
  use Ecto.Migration

  def change do
    create table(:scopes) do
      add :scope_name, :string, null: false
    end

    create unique_index(:scopes, :scope_name)
  end
end
