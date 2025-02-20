defmodule Guard.Repo.Migrations.AddAuditTrigger do
  use Ecto.Migration

  def up do
    execute(create_uuid_v4_extension())
    execute(create_audit_function())
    execute(trigger_audit_function())
  end

  def down do
    execute(remove_audit_trigger())
    execute(remove_audit_function())
  end

  defp create_uuid_v4_extension, do: """
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
  """

  defp create_audit_function, do: """
    CREATE OR REPLACE FUNCTION audit_global_permissions()
    RETURNS TRIGGER AS $audit_global_permissions$
    DECLARE
      new_value TEXT;
      old_value TEXT;
      key TEXT;
    BEGIN
      IF TG_OP = 'INSERT' THEN
        key = NEW.key;
      ELSE
        key = OLD.key;
      END IF;

      IF (key LIKE '%org:*_project:*') THEN
        IF TG_OP = 'INSERT' THEN
          new_value=NEW.value;
          old_value='';
        ELSEIF TG_OP = 'DELETE' THEN
          new_value='';
          old_value=OLD.value;
        ELSEIF TG_OP = 'UPDATE' THEN
          new_value=NEW.value;
          old_value=OLD.value;
        END IF;

        INSERT INTO global_permissions_audit_log (id, key, old_value, new_value, query_operation, notified, inserted_at, updated_at)
        VALUES (uuid_generate_v4(), key, old_value, new_value, TG_OP, false, now(), now());
      END IF;

    RETURN NULL;
    END;
    $audit_global_permissions$ LANGUAGE plpgsql;
  """

  defp trigger_audit_function, do: """
    CREATE TRIGGER user_permissions_key_value_store_trigger
    AFTER INSERT OR UPDATE OR DELETE ON user_permissions_key_value_store
    FOR EACH ROW EXECUTE PROCEDURE audit_global_permissions(); 
  """

  defp remove_audit_trigger, do: """
    DROP TRIGGER user_permissions_key_value_store_trigger ON user_permissions_key_value_store;
  """

  defp remove_audit_function, do: """
    DROP FUNCTION audit_global_permissions();
  """

  defp remove_uuid_v4_extension, do: """
    DROP EXTENSION IF EXISTS "uuid-ossp";
  """
end
