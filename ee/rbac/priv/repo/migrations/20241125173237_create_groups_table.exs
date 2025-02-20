defmodule Rbac.Repo.Migrations.CreateGroupsTable do
  use Ecto.Migration

  def change do
    create table(:groups, primary_key: false) do
      add :id, references(:subjects, on_delete: :delete_all), primary_key: true
      add :org_id, :binary_id, null: false
      add :creator_id, :binary_id, null: false
      add :description, :string, null: false
    end
  end
end
