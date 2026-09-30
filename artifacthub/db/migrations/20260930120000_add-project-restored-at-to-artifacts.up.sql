begin;

ALTER TABLE artifacts ADD COLUMN IF NOT EXISTS project_restored_at timestamp;

commit;
