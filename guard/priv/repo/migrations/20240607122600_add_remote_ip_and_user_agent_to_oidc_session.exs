defmodule Guard.Repo.Migrations.AddRemoteIpAndUserAgentToOidcSession do
  use Ecto.Migration

  def change do
    alter table(:oidc_sessions) do
      add :ip_address, :string, null: false, default: ""
      add :user_agent, :string, null: false, default: ""
    end
  end
end
