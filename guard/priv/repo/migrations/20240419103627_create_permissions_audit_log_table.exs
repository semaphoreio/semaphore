defmodule Guard.Repo.Migrations.CreatePermissionsAuditLogTable do
  use Ecto.Migration

  def change do
    create table(:global_permissions_audit_log) do
      add :key, :string, null: false
      add :old_value, :string, null: false
      add :new_value, :string, null: false
      add :query_operation, :string, null: false
      add :notified, :boolean, default: false, null: false

      timestamps()
    end
  end
end
