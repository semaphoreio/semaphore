defmodule Guard.Repo.Migrations.AddIdempotencyTokenToOktaIntegrations do
  use Ecto.Migration

  def change do
    alter table(:okta_integrations) do
      add :idempotency_token, :string
    end

    create unique_index(:okta_integrations, [:idempotency_token])
  end
end
