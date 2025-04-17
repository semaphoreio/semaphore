begin;

CREATE TABLE stage_events (
  id          uuid NOT NULL DEFAULT uuid_generate_v4(),
  stage_id    uuid NOT NULL,
  event_id    uuid NOT NULL,
  source_id   uuid NOT NULL,
  source_type CHARACTER VARYING(64) NOT NULL,
  state       CHARACTER VARYING(64) NOT NULL,
  created_at  TIMESTAMP NOT NULL,
  approved_at TIMESTAMP,
  approved_by uuid,

  PRIMARY KEY (id),
  FOREIGN KEY (stage_id) REFERENCES stages(id)
);

CREATE INDEX uix_stage_events_stage ON stage_events USING btree (stage_id);
CREATE INDEX uix_stage_events_source ON stage_events USING btree (source_id);

commit;
