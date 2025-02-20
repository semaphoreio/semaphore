begin;

ALTER TABLE agents ADD COLUMN assigned_job_id       uuid;
ALTER TABLE agents ADD COLUMN job_assigned_at       timestamp;
ALTER TABLE agents ADD COLUMN job_stop_requested_at timestamp;

commit;
