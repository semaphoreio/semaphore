defmodule Guard.Repo.Migrations.CreateGroupsTable do
  use Ecto.Migration

  def change do
    create table(:groups, primary_key: false) do
      add :id, references(:subjects, on_delete: :delete_all), primary_key: true
      add :group_name, :string, null: false
      add :org_id, :binary_id, null: false
    end
    create unique_index(:groups, [:group_name, :org_id],
     comment: "One organization can't have multiple groups with same name")
  end
end
