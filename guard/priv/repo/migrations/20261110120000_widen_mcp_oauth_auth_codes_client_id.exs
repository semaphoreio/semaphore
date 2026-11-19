defmodule Guard.Repo.Migrations.WidenMcpOauthAuthCodesClientId do
  use Ecto.Migration

  def change do
    alter table(:mcp_oauth_auth_codes) do
      modify :client_id, :text, null: false, from: {:string, null: false}
    end
  end
end
