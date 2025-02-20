defmodule Ppl.EctoRepo.Migrations.RemovePipelineStateChangeTriggers do
  use Ecto.Migration

  def up do
    # Drop triggers first
    execute "DROP TRIGGER IF EXISTS ppl_state_changes ON pipelines;"
    execute "DROP TRIGGER IF EXISTS ppl_created ON pipelines;"

    flush()

    # Then drop functions
    execute "DROP FUNCTION IF EXISTS audit_ppl_state_change_func();"
    execute "DROP FUNCTION IF EXISTS audit_ppl_created_func();"
  end

  def down do
    # Recreate functions
    execute """
    CREATE OR REPLACE FUNCTION audit_ppl_created_func()
      RETURNS TRIGGER AS
    $BODY$

    BEGIN
     INSERT INTO pipeline_state_changes(ppl_id, ppl_state, ppl_changed_state_on,
                 inserted_at, updated_at, state)
     VALUES(NEW.ppl_id, NEW.state, NEW.updated_at, now(), now(), 'for_publishing');

     RETURN NEW;
    END;

    $BODY$
    LANGUAGE plpgsql;
    """

    execute """
    CREATE OR REPLACE FUNCTION audit_ppl_state_change_func()
      RETURNS TRIGGER AS
    $BODY$

    BEGIN
     IF NEW.state <> OLD.state THEN
     INSERT INTO pipeline_state_changes(ppl_id, ppl_state, ppl_changed_state_on,
                 inserted_at, updated_at, state)
     VALUES(NEW.ppl_id, NEW.state, NEW.updated_at, now(), now(), 'for_publishing');
     END IF;

     RETURN NEW;
    END;

    $BODY$
    LANGUAGE plpgsql;
    """

    flush()

    # Recreate triggers
    execute """
    CREATE TRIGGER ppl_created
      AFTER INSERT
      ON pipelines
      FOR EACH ROW
      EXECUTE PROCEDURE audit_ppl_created_func();
    """

    execute """
    CREATE TRIGGER ppl_state_changes
      AFTER UPDATE
      ON pipelines
      FOR EACH ROW
      EXECUTE PROCEDURE audit_ppl_state_change_func();
    """
  end
end
