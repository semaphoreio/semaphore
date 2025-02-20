defmodule Guard.Repo.Migrations.AddScimTokenHashToOktaIntegration do
  use Ecto.Migration

  def change do
    alter table(:okta_integrations) do
      add :scim_token_hash, :string
    end
  end
end
