begin;

ALTER TABLE stages ADD COLUMN updated_at TIMESTAMP;
ALTER TABLE stages ADD COLUMN updated_by UUID;

commit;
