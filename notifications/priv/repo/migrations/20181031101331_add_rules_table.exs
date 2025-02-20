defmodule Notifications.Repo.Migrations.AddRulesTable do
  use Ecto.Migration

  def change do
    create table(:rules, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :org_id, :binary_id, null: false
      add :notification_id, references("notifications", type: :binary_id, on_delete: :delete_all)
      add :name, :string

      # slack, email, or webhook settings
      add :slack, :map
      add :email, :map
      add :webhook, :map

      timestamps()
    end

    create index(:rules, [:org_id])
  end
end
