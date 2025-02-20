begin;

ALTER TABLE repositories ADD COLUMN integration_type character varying(100);

commit;
