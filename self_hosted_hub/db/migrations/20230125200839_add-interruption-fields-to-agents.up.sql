begin;

ALTER TABLE agents ADD interrupted_at timestamp;
ALTER TABLE agents ADD interruption_grace_period int DEFAULT 0;

commit;
