begin;

CREATE TABLE events (
  id              uuid NOT NULL DEFAULT uuid_generate_v4(),
  source_id       uuid NOT NULL,
  received_at     TIMESTAMP NOT NULL,
  raw             jsonb NOT NULL,
  state           CHARACTER VARYING(64) NOT NULL,

  PRIMARY KEY (id),
  FOREIGN KEY (source_id) REFERENCES event_sources(id)
);

CREATE INDEX uix_events_source ON events USING btree (source_id);

commit;
