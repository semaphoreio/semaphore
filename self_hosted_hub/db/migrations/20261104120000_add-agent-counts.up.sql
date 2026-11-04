BEGIN;

-- Number of registered agents per organization, kept in sync with the agents
-- table by a trigger. Registration checks the organization quota against this
-- row instead of counting the agents table under an organization-wide lock.
--
-- Everything below runs in one transaction. The table lock taken below blocks
-- writes to agents until the transaction commits, so the backfill sees a stable
-- table and no change is lost between creating the trigger and filling the counts.
-- The backfill is one aggregate over agents, so writes wait for about that long.
--
-- Rollout notes:
--
-- * While old and new pods both serve registrations, the quota can be exceeded
--   by one agent per old/new pair registering at the same time at the quota
--   boundary: old pods count committed agents under the advisory lock and don't
--   see an uncommitted insert from a new pod. The count stays exact, and the
--   sync quota check disables the extra agents afterwards. This ends when the
--   rollout ends.
--
-- * To roll back, run this migration down first, then deploy the older image.
--   An older image doesn't have this migration file, so its startup
--   `migrate up` fails while the database is at this version.
--
-- * Every statement is idempotent. If this migration fails (for example, the
--   lock below can't be taken in time), the database is left at this version,
--   marked dirty, and pods fail on startup. Recover with
--   `migrate force 20261103150000` and restart the pods, which re-runs it.

-- Take the lock CREATE TRIGGER needs before creating anything, in short attempts.
-- Waiting for a lock queues every write to agents behind the waiting request,
-- so each attempt gives up after 100ms, letting the queued writes through,
-- and tries again. All writers of agents are short transactions, so this
-- normally succeeds on the first attempts. It gives up after about 2 minutes,
-- well within the pods' startup probe budget, instead of waiting forever.
DO $$
DECLARE
  attempt integer := 0;
BEGIN
  LOOP
    BEGIN
      PERFORM set_config('lock_timeout', '100ms', true);
      LOCK TABLE agents IN SHARE ROW EXCLUSIVE MODE;
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

CREATE TABLE IF NOT EXISTS agent_counts (
  organization_id uuid PRIMARY KEY,
  registered integer NOT NULL DEFAULT 0
);

CREATE OR REPLACE FUNCTION agent_counts_track() RETURNS trigger AS $$
BEGIN
  IF TG_OP IN ('UPDATE', 'DELETE') AND OLD.state = 'registered' THEN
    UPDATE agent_counts SET registered = registered - 1 WHERE organization_id = OLD.organization_id;
  END IF;

  IF TG_OP IN ('INSERT', 'UPDATE') AND NEW.state = 'registered' THEN
    INSERT INTO agent_counts (organization_id, registered) VALUES (NEW.organization_id, 1)
    ON CONFLICT (organization_id) DO UPDATE SET registered = agent_counts.registered + 1;
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS agent_counts_on_insert_or_delete ON agents;
CREATE TRIGGER agent_counts_on_insert_or_delete
  AFTER INSERT OR DELETE ON agents
  FOR EACH ROW EXECUTE PROCEDURE agent_counts_track();

-- Agent syncs update agents constantly, but only state changes move the count.
DROP TRIGGER IF EXISTS agent_counts_on_update ON agents;
CREATE TRIGGER agent_counts_on_update
  AFTER UPDATE OF state, organization_id ON agents
  FOR EACH ROW
  WHEN (OLD.state IS DISTINCT FROM NEW.state OR OLD.organization_id IS DISTINCT FROM NEW.organization_id)
  EXECUTE PROCEDURE agent_counts_track();

DELETE FROM agent_counts;
INSERT INTO agent_counts (organization_id, registered)
  SELECT organization_id, COUNT(*) FROM agents WHERE state = 'registered' GROUP BY organization_id
ON CONFLICT (organization_id) DO UPDATE SET registered = EXCLUDED.registered;

COMMIT;
