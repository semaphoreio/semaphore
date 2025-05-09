begin;

ALTER TABLE stages DROP COLUMN updated_at;
ALTER TABLE stages DROP COLUMN updated_by;

commit;
