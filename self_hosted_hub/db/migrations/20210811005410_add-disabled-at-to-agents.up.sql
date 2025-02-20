begin;

ALTER TABLE agents ADD COLUMN disabled_at timestamp;

commit;
