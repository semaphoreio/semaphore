begin;

ALTER TABLE agents ADD token_hash character varying(250);

commit;
