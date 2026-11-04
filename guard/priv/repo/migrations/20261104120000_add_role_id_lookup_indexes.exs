defmodule Guard.Repo.Migrations.AddRoleIdLookupIndexes do
  use Ecto.Migration

  # CREATE INDEX CONCURRENTLY cannot run inside a transaction or under the
  # migration lock. IF NOT EXISTS / IF EXISTS keep it safe to re-run.
  @disable_ddl_transaction true
  @disable_migration_lock true

  # subject_role_bindings(role_id): the foreign key to rbac_roles has no index,
  # so listing a role's bindings and the foreign key check on role deletion
  # scan the whole table.
  #
  # role_inheritance(inherited_role_id): only (inheriting_role_id, ...) is
  # indexed, so "is this role inherited by another role" and the cascade on
  # role deletion scan the whole table.
  def up do
    execute("""
    CREATE INDEX CONCURRENTLY IF NOT EXISTS subject_role_bindings_role_id_index
    ON subject_role_bindings (role_id)
    """)

    execute("""
    CREATE INDEX CONCURRENTLY IF NOT EXISTS role_inheritance_inherited_role_id_index
    ON role_inheritance (inherited_role_id)
    """)
  end

  def down do
    execute("DROP INDEX CONCURRENTLY IF EXISTS subject_role_bindings_role_id_index")
    execute("DROP INDEX CONCURRENTLY IF EXISTS role_inheritance_inherited_role_id_index")
  end
end
