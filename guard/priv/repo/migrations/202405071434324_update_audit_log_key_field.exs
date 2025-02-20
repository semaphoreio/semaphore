defmodule Guard.Repo.Migrations.ModifyAuditLogTable do
  use Ecto.Migration

  def change do
    alter table(:global_permissions_audit_log) do
      modify :old_value, :text, null: false
      modify :new_value, :text, null: false
    end
  end
end
