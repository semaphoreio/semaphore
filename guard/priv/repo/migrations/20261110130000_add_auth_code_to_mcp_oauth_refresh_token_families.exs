defmodule Guard.Repo.Migrations.AddAuthCodeToMcpOauthRefreshTokenFamilies do
  use Ecto.Migration

  def change do
    alter table(:mcp_oauth_refresh_token_families) do
      add :auth_code_id, references(:mcp_oauth_auth_codes, type: :uuid, on_delete: :nilify_all)
    end

    create index(:mcp_oauth_refresh_token_families, [:auth_code_id])
  end
end
