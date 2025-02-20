BEGIN;

ALTER TABLE pipeline_summaries
DROP COLUMN created_at,
DROP COLUMN updated_at;

ALTER TABLE job_summaries
DROP COLUMN created_at,
DROP COLUMN updated_at;

END;
