defmodule Guard.Repo.Migrations.CreateMcpGrantsAndConsentChallenges do
  use Ecto.Migration

  def change do
    create table(:mcp_grants, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:user_id, references(:rbac_users, type: :uuid, on_delete: :delete_all), null: false)
      add(:client_id, :string, null: false)
      add(:client_name, :string)
      add(:tool_scopes, {:array, :string}, default: [], null: false)
      add(:expires_at, :utc_datetime)
      add(:revoked_at, :utc_datetime)
      add(:last_used_at, :utc_datetime)

      timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
    end

    create(index(:mcp_grants, [:user_id]))
    create(index(:mcp_grants, [:client_id]))
    create(index(:mcp_grants, [:user_id, :client_id]))
    create(index(:mcp_grants, [:expires_at]))
    create(index(:mcp_grants, [:revoked_at]))

    create table(:mcp_grant_org_grants, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:grant_id, references(:mcp_grants, type: :uuid, on_delete: :delete_all), null: false)
      add(:org_id, :uuid, null: false)
      add(:org_name, :string)
      add(:can_view, :boolean, default: false, null: false)
      add(:can_run_workflows, :boolean, default: false, null: false)

      timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
    end

    create(unique_index(:mcp_grant_org_grants, [:grant_id, :org_id]))
    create(index(:mcp_grant_org_grants, [:org_id]))

    create table(:mcp_grant_project_grants, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:grant_id, references(:mcp_grants, type: :uuid, on_delete: :delete_all), null: false)
      add(:project_id, :uuid, null: false)
      add(:org_id, :uuid, null: false)
      add(:project_name, :string)
      add(:can_view, :boolean, default: false, null: false)
      add(:can_run_workflows, :boolean, default: false, null: false)
      add(:can_view_logs, :boolean, default: false, null: false)

      timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
    end

    create(unique_index(:mcp_grant_project_grants, [:grant_id, :project_id]))
    create(index(:mcp_grant_project_grants, [:org_id]))
    create(index(:mcp_grant_project_grants, [:project_id]))

    create table(:mcp_oauth_consent_challenges, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:user_id, references(:rbac_users, type: :uuid, on_delete: :delete_all), null: false)
      add(:client_id, :string, null: false)
      add(:client_name, :string)
      add(:redirect_uri, :text, null: false)
      add(:code_challenge, :string, null: false)
      add(:code_challenge_method, :string, null: false)
      add(:state, :text)
      add(:requested_scope, :string)
      add(:expires_at, :utc_datetime, null: false)
      add(:consumed_at, :utc_datetime)

      timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
    end

    create(index(:mcp_oauth_consent_challenges, [:user_id]))
    create(index(:mcp_oauth_consent_challenges, [:client_id]))
    create(index(:mcp_oauth_consent_challenges, [:user_id, :client_id]))
    create(index(:mcp_oauth_consent_challenges, [:expires_at]))
    create(index(:mcp_oauth_consent_challenges, [:consumed_at]))

    alter table(:mcp_oauth_auth_codes) do
      add(:grant_id, references(:mcp_grants, type: :uuid, on_delete: :nilify_all))
    end

    create(index(:mcp_oauth_auth_codes, [:grant_id]))
  end
end
