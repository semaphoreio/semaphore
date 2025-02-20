begin;

ALTER TABLE agents RENAME COLUMN last_hearthbeat_at TO last_sync_at;
ALTER TABLE agents ADD COLUMN last_sync_state varchar;
ALTER TABLE agents ADD COLUMN last_sync_job_id varchar;

commit;
