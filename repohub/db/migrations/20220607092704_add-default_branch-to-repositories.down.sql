begin;

ALTER TABLE repositories DROP COLUMN IF EXISTS default_branch;

commit;
