defmodule Guard.Repo.Migrations.CreateMcpOauthRefreshTokens do
  use Ecto.Migration

  def change do
    create table(:mcp_oauth_refresh_tokens, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :token_hash, :string, null: false
      add :family_id, :uuid, null: false
      add :family_expires_at, :utc_datetime, null: false
      add :client_id, :string, null: false
      add :user_id, references(:rbac_users, type: :uuid, on_delete: :delete_all), null: false
      add :expires_at, :utc_datetime, null: false
      add :used_at, :utc_datetime
      add :revoked_at, :utc_datetime

      timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
    end

    create unique_index(:mcp_oauth_refresh_tokens, [:token_hash])
    create index(:mcp_oauth_refresh_tokens, [:family_id])
    create index(:mcp_oauth_refresh_tokens, [:client_id])
    create index(:mcp_oauth_refresh_tokens, [:user_id])
    create index(:mcp_oauth_refresh_tokens, [:expires_at])
  end
end
