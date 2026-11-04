-- No CREATE INDEX CONCURRENTLY here: every hub pod runs `migrate up` on startup,
-- and a concurrent build waits for the other pods' sessions, which are waiting
-- for the migration lock this pod holds. That deadlock can leave an INVALID index
-- and a dirty migration version.
--
-- Large installations should build this index by hand first, with
-- CREATE INDEX CONCURRENTLY and the same name. This migration then only checks
-- that it exists and is valid, without locking the table. Otherwise the index is
-- built here with a plain CREATE INDEX, which blocks writes to agents while it builds.
-- An INVALID leftover from an interrupted concurrent build is dropped and rebuilt.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_index
    WHERE indexrelid = to_regclass('public.index_agents_on_org_and_state') AND NOT indisvalid
  ) THEN
    DROP INDEX public.index_agents_on_org_and_state;
  END IF;

  IF to_regclass('public.index_agents_on_org_and_state') IS NULL THEN
    CREATE INDEX index_agents_on_org_and_state ON agents (organization_id, state);
  END IF;
END
$$;
