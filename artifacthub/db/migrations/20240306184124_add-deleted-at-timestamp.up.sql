begin;

ALTER TABLE artifacts ADD COLUMN deleted_at timestamp;

commit;
