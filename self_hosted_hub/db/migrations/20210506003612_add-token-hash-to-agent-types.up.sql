begin;

ALTER TABLE agent_types ADD token_hash character varying(250);

commit;
