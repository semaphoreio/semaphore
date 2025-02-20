defmodule Secrethub.Repo.Migrations.CreateNotificationsTable do
  use Ecto.Migration

  def change do
    create table(:notifications, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :org_id, :binary_id
      add :name, :string
      add :spec, :map

      timestamps()
    end

    create index(:notifications, [:name])
    create index(:notifications, [:org_id])

    create unique_index(:notifications, [:org_id, :name], name: :unique_names_in_organization)
  end
end
