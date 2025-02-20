defmodule Guard.Repo.Migrations.OktaIntegrationsAddSsoURL do
  use Ecto.Migration

  def change do
    alter table(:okta_integrations) do
      add :sso_url, :string, null: true
    end
  end
end
