begin;

CREATE TABLE stage_events (
  id         uuid NOT NULL DEFAULT uuid_generate_v4(),
  stage_id   uuid NOT NULL,
  source_id  uuid NOT NULL,
  state      CHARACTER VARYING(64) NOT NULL,
  created_at TIMESTAMP NOT NULL,

  PRIMARY KEY (id),
  UNIQUE (stage_id, source_id),
  FOREIGN KEY (stage_id) REFERENCES stages(id)
);

CREATE INDEX uix_stage_events_stage ON stage_events USING btree (stage_id);
CREATE INDEX uix_stage_events_source ON stage_events USING btree (source_id);

commit;
