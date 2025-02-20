defmodule Guard.Repo.Migrations.AddOktaIntegrations do
  use Ecto.Migration

  def change do
    create table("okta_integrations") do
      add(:org_id, :binary_id, null: false)
      add(:creator_id, :binary_id, null: false)

      add(:saml_issuer, :string, null: false)
      add(:saml_certificate_fingerprint, :string, null: false)

      timestamps()
    end

    create(index("okta_integrations", :org_id, unique: true))
  end
end
