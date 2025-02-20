begin;

ALTER TABLE repositories ADD COLUMN default_branch character varying(100);

commit;
