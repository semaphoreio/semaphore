begin;

ALTER TABLE retention_policies ADD COLUMN scheduled_for_cleaning_at timestamp;
ALTER TABLE retention_policies ADD COLUMN last_cleaned_at timestamp;

commit;
