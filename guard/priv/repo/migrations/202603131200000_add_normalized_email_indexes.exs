defmodule Guard.Repo.Migrations.AddNormalizedEmailIndexes do
  use Ecto.Migration

  def up do
    execute("""
    CREATE UNIQUE INDEX IF NOT EXISTS rbac_users_normalized_email_index
    ON rbac_users (LOWER(TRIM(email)))
    """)

    execute("""
    CREATE UNIQUE INDEX IF NOT EXISTS okta_users_integration_id_normalized_email_index
    ON okta_users (integration_id, LOWER(TRIM(email)))
    """)

    execute("""
    CREATE UNIQUE INDEX IF NOT EXISTS saml_jit_users_integration_id_normalized_email_index
    ON saml_jit_users (integration_id, LOWER(TRIM(email)))
    """)
  end

  def down do
    execute("DROP INDEX IF EXISTS rbac_users_normalized_email_index")
    execute("DROP INDEX IF EXISTS okta_users_integration_id_normalized_email_index")
    execute("DROP INDEX IF EXISTS saml_jit_users_integration_id_normalized_email_index")
  end
end
