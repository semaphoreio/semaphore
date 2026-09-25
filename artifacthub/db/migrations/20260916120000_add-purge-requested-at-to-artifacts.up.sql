begin;

ALTER TABLE artifacts ADD COLUMN IF NOT EXISTS purge_requested_at timestamp;

commit;
