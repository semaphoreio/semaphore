defmodule Guard.Repo.Migrations.CreateSamlJitUsers do
  use Ecto.Migration

  def change do
    create table("saml_jit_users") do
      add(:integration_id, :binary_id, null: false)
      add(:org_id, :binary_id, null: false)
      add(:attributes, :jsonb, null: false)
      add(:state, :string, null: false)
      add(:user_id, :uuid)
      add(:email, :string)

      timestamps()
    end

    create(unique_index(:saml_jit_users, [:integration_id, :email]))
  end
end
