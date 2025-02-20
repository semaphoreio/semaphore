ALTER TABLE pipeline_summaries
ADD COLUMN created_at  timestamp without time zone not null default (now() at time zone 'utc'),
ADD COLUMN updated_at  timestamp without time zone not null default (now() at time zone 'utc');

ALTER TABLE job_summaries
ADD COLUMN created_at  timestamp without time zone not null default (now() at time zone 'utc'),
ADD COLUMN updated_at  timestamp without time zone not null default (now() at time zone 'utc');
