defmodule Rbac.Repo.Migrations.AddCaseInsensitiveEmailIndexes do
  use Ecto.Migration

  def up do
    # Drop existing unique indexes
    drop unique_index(:rbac_users, :email)
    drop unique_index(:okta_users, [:integration_id, :email])
    drop unique_index(:saml_jit_users, [:integration_id, :email])

    # Create case-insensitive unique indexes using LOWER()
    execute "CREATE UNIQUE INDEX rbac_users_email_index ON rbac_users (LOWER(email))"

    execute "CREATE UNIQUE INDEX okta_users_integration_id_email_index ON okta_users (integration_id, LOWER(email))"

    execute "CREATE UNIQUE INDEX saml_jit_users_integration_id_email_index ON saml_jit_users (integration_id, LOWER(email))"
  end

  def down do
    execute "DROP INDEX rbac_users_email_index"
    execute "DROP INDEX okta_users_integration_id_email_index"
    execute "DROP INDEX saml_jit_users_integration_id_email_index"

    create unique_index(:rbac_users, :email)
    create unique_index(:okta_users, [:integration_id, :email])
    create unique_index(:saml_jit_users, [:integration_id, :email])
  end
end
