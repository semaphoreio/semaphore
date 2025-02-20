defmodule Guard.Repo.Migrations.AddInheritedTypeToBindingSource do
  use Ecto.Migration

  ###
  ### This query efectively adds one more value to enum type
  ###
  ### There is a dedicated ALTER TYPE _ ADD VALUE command, but it can not be executed
  ### Within the transaction, and ecto executes commands inside the transaction, so it can't
  ### be used here, and we have this long transaction to achive the same thing
  ###
  @sql_commands_for_altering_enum_type [
    "ALTER TYPE role_binding_scope RENAME TO deprecated;",
    "CREATE TYPE role_binding_scope AS ENUM ('github', 'bitbucket', 'gitlab', 'manually_assigned', 'okta', 'inherited_from_org_role');",
    "ALTER TABLE subject_role_bindings
      ALTER COLUMN binding_source TYPE role_binding_scope USING binding_source::text::role_binding_scope;",
    "DROP TYPE deprecated;"
  ]

  def change do
    Enum.each(@sql_commands_for_altering_enum_type, &execute/1)
  end
end
