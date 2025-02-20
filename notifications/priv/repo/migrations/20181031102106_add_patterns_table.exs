defmodule Notifications.Repo.Migrations.AddPatternsTable do
  use Ecto.Migration

  def change do
    create table(:patterns, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :org_id, :binary_id, null: false
      add :rule_id, references("rules", type: :binary_id, on_delete: :delete_all)

      add :term, :string, null: false
      add :type, :string, null: false
      add :regex, :boolean, null: false

      timestamps()
    end

    create index(:patterns, [:org_id])
    create index(:patterns, [:term, :type, :regex])
  end
end
