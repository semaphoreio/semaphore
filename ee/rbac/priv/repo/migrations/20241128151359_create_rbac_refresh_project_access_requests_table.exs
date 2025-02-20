defmodule Rbac.Repo.Migrations.CreateRbacRefreshProjectAccessRequestsTable do
  use Ecto.Migration

  def change do
    create table(:rbac_refresh_project_access_requests, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :state, :string, null: false
      add :org_id, :binary_id, null: false
      add :user_id, :binary_id, null: false
      add :projects, :map, null: false

      timestamps()
    end

    create index(:rbac_refresh_project_access_requests, [:inserted_at])
    create unique_index(:rbac_refresh_project_access_requests, [:state, :org_id, :user_id], where: "state = 'pending'")
  end
end
