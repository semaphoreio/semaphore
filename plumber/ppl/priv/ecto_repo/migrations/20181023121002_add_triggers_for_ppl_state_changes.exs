defmodule Ppl.EctoRepo.Migrations.AddTriggersForPplStateChangeEvents do
  use Ecto.Migration

  def up  do
    create table(:pipeline_state_changes) do
      add :ppl_id, references(:pipeline_requests, type: :uuid, on_delete: :delete_all), null: false
      add :ppl_state, :string
      add :ppl_changed_state_on, :utc_datetime_usec
      add :published_to,  {:array, :string}, default: []
      add :state, :string
      add :result, :string
      add :in_scheduling, :boolean, default: false
      add :error_description, :text, default: ""
      add :recovery_count, :integer, default: 0, null: false

      timestamps(type: :naive_datetime_usec)
    end

    flush()

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

  def down do
    execute "DROP TRIGGER ppl_state_changes ON pipelines;"
    execute "DROP TRIGGER ppl_created ON pipelines;"
    execute "DROP FUNCTION IF EXISTS audit_ppl_state_change_func();"
    execute "DROP FUNCTION IF EXISTS audit_ppl_created_func();"
    execute "DROP TABLE pipeline_state_changes;"
  end
end
