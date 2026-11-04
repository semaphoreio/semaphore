BEGIN;

-- Number of registered agents per organization, kept in sync with the agents
-- table by a trigger. Registration checks the organization quota against this
-- row instead of counting the agents table under an organization-wide lock.
--
-- Everything below runs in one transaction. CREATE TRIGGER blocks writes to
-- agents until the transaction commits, so the backfill sees a stable table
-- and no change is lost between creating the trigger and filling the counts.

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

INSERT INTO agent_counts (organization_id, registered)
  SELECT organization_id, COUNT(*) FROM agents WHERE state = 'registered' GROUP BY organization_id
ON CONFLICT (organization_id) DO UPDATE SET registered = EXCLUDED.registered;

COMMIT;
