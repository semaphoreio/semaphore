ALTER TABLE agents ADD COLUMN IF NOT EXISTS job_finished_at timestamp DEFAULT NULL;
