begin;

ALTER TABLE repositories DROP COLUMN IF EXISTS integration_type;

commit;
