BEGIN;

DROP TRIGGER IF EXISTS agent_counts_on_update ON agents;
DROP TRIGGER IF EXISTS agent_counts_on_insert_or_delete ON agents;
DROP FUNCTION IF EXISTS agent_counts_track();
DROP TABLE IF EXISTS agent_counts;

COMMIT;
