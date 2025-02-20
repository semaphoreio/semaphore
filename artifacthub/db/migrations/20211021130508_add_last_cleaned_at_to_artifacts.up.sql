begin;

ALTER TABLE artifacts ADD COLUMN last_cleaned_at timestamp;

commit;
