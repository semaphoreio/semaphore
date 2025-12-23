defmodule Guard.Repo.Migrations.CreateMcpGrants do
  use Ecto.Migration

  def change do
    # Main grants table
    create table(:mcp_grants, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :user_id, references(:rbac_users, type: :uuid, on_delete: :delete_all), null: false
      add :client_id, :string, null: false
      add :client_name, :string
      add :tool_scopes, {:array, :string}, default: []
      add :expires_at, :utc_datetime
      add :revoked_at, :utc_datetime
      add :last_used_at, :utc_datetime
      add :created_by_ip, :string
      add :user_agent, :text

      timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
    end

    create index(:mcp_grants, [:user_id])
    create index(:mcp_grants, [:client_id])
    create index(:mcp_grants, [:revoked_at])

    # Organization grants table
    create table(:mcp_grant_orgs, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :grant_id, references(:mcp_grants, type: :uuid, on_delete: :delete_all), null: false
      add :org_id, :binary_id, null: false
      add :org_name, :string
      add :can_view, :boolean, default: false, null: false
      add :can_run_workflows, :boolean, default: false, null: false

      timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
    end

    create index(:mcp_grant_orgs, [:grant_id])
    create index(:mcp_grant_orgs, [:org_id])
    create unique_index(:mcp_grant_orgs, [:grant_id, :org_id])

    # Project grants table
    create table(:mcp_grant_projects, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :grant_id, references(:mcp_grants, type: :uuid, on_delete: :delete_all), null: false
      add :project_id, :binary_id, null: false
      add :org_id, :binary_id, null: false
      add :project_name, :string
      add :can_view, :boolean, default: false, null: false
      add :can_run_workflows, :boolean, default: false, null: false
      add :can_view_logs, :boolean, default: false, null: false

      timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
    end

    create index(:mcp_grant_projects, [:grant_id])
    create index(:mcp_grant_projects, [:project_id])
    create index(:mcp_grant_projects, [:org_id])
    create unique_index(:mcp_grant_projects, [:grant_id, :project_id])
  end
end
