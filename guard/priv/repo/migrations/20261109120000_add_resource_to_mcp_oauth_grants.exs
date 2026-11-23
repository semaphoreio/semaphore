defmodule Guard.Repo.Migrations.AddResourceToMcpOauthGrants do
  use Ecto.Migration

  def change do
    alter table(:mcp_oauth_auth_codes) do
      add :resource, :text
    end

    alter table(:mcp_oauth_refresh_token_families) do
      add :resource, :text
    end
  end
end
