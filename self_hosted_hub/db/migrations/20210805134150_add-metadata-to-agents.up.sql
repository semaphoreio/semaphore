begin;

ALTER TABLE agents ADD version    text       DEFAULT '';
ALTER TABLE agents ADD os         text       DEFAULT '';
ALTER TABLE agents ADD arch       text       DEFAULT '';
ALTER TABLE agents ADD pid        smallint   DEFAULT 0;
ALTER TABLE agents ADD hostname   text       DEFAULT '';
ALTER TABLE agents ADD user_agent text       DEFAULT '';
ALTER TABLE agents ADD ip_address text       DEFAULT '';

commit;
