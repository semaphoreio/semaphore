defmodule Guard.Repo.Migrations.CreateProjectAccessKeyValueStore do
  use Ecto.Migration

  def change do
    create table(:project_access_key_value_store, primary_key: false) do
      add :key, :string, primary_key: true
      add :value, :text, null: false

      timestamps(default: fragment("now()"))
    end
  end
end
