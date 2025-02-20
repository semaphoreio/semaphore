defmodule Rbac.Repo.Migrations.CreateGlobalPermissionsAuditLogTable do
  use Ecto.Migration

  def change do
    create table(:global_permissions_audit_log) do
      add :key, :string, null: false
      add :old_value, :text, null: false
      add :new_value, :text, null: false
      add :query_operation, :string, null: false
      add :notified, :boolean, default: false, null: false

      timestamps()
    end
  end
end
