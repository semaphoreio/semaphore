defmodule Guard.Repo.Migrations.CreateMcpOauthAuthCodes do
  use Ecto.Migration

  def change do
    create table(:mcp_oauth_auth_codes, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :code, :string, null: false
      add :client_id, :string, null: false
      add :user_id, references(:rbac_users, type: :uuid, on_delete: :delete_all), null: false
      add :redirect_uri, :text, null: false
      add :code_challenge, :string, null: false
      add :grant_id, references(:mcp_grants, type: :uuid, on_delete: :delete_all), null: false
      add :expires_at, :utc_datetime, null: false
      add :used_at, :utc_datetime

      timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
    end

    create unique_index(:mcp_oauth_auth_codes, [:code])
    create index(:mcp_oauth_auth_codes, [:client_id])
    create index(:mcp_oauth_auth_codes, [:user_id])
    create index(:mcp_oauth_auth_codes, [:grant_id])
    create index(:mcp_oauth_auth_codes, [:expires_at])
  end
end
