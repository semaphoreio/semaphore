begin;

ALTER TABLE artifacts ADD COLUMN purge_requested_at timestamp;

commit;
