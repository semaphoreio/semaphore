-- Run this before rolling back to an image without this migration:
-- older images fail their startup `migrate up` while the database is at a
-- version they don't know. Older images don't use agent_counts.

BEGIN;

-- Same short lock attempts as the up migration: DROP TRIGGER needs an
-- exclusive lock on agents, and a long wait would queue every write behind it.
DO $$
DECLARE
  attempt integer := 0;
BEGIN
  LOOP
    BEGIN
      PERFORM set_config('lock_timeout', '100ms', true);
      LOCK TABLE agents IN ACCESS EXCLUSIVE MODE;
      PERFORM set_config('lock_timeout', '0', true);
      RETURN;
    EXCEPTION WHEN lock_not_available THEN
      attempt := attempt + 1;
      IF attempt >= 600 THEN
        RAISE EXCEPTION 'could not lock agents after % attempts', attempt;
      END IF;
      PERFORM pg_sleep(0.1);
    END;
  END LOOP;
END
$$;

DROP TRIGGER IF EXISTS agent_counts_on_update ON agents;
DROP TRIGGER IF EXISTS agent_counts_on_insert_or_delete ON agents;
DROP FUNCTION IF EXISTS agent_counts_track();
DROP TABLE IF EXISTS agent_counts;

COMMIT;
