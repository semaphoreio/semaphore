defmodule Rbac.Repo.Migrations.CreateOktaIntegrationsTable do
  use Ecto.Migration

  def change do
    create table("okta_integrations") do
      add(:org_id, :binary_id, null: false)
      add(:creator_id, :binary_id, null: false)

      add(:saml_issuer, :string, null: false)
      add(:saml_certificate_fingerprint, :string, null: false)
      add(:scim_token_hash, :string)
      add(:idempotency_token, :string)
      add(:sso_url, :string, null: true)

      timestamps()
    end

    create(index("okta_integrations", :org_id, unique: true))
    create(unique_index(:okta_integrations, [:idempotency_token]))
  end
end
