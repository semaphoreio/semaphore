begin;

ALTER TABLE artifacts ADD COLUMN IF NOT EXISTS purge_requested_at timestamp;
ALTER TABLE artifacts ADD COLUMN IF NOT EXISTS project_restored_at timestamp;

commit;
