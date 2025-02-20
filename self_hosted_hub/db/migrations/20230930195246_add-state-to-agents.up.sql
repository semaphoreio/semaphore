begin;

ALTER TABLE agents ADD COLUMN state text DEFAULT 'registered';
ALTER TABLE agents ADD COLUMN disconnected_at timestamp DEFAULT NULL;

commit;
