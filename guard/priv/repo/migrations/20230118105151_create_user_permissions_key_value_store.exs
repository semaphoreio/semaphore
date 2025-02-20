defmodule Guard.Repo.Migrations.CreateUserPermissionsKeyValueStore do
  use Ecto.Migration

  def change do
    create table(:user_permissions_key_value_store, primary_key: false) do
      add :key, :string, primary_key: true
      add :value, :text, null: false

      timestamps(default: fragment("now()"))
    end
  end
end
