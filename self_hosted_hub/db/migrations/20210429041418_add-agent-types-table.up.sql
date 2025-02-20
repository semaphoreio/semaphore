begin;

CREATE TABLE agent_types (
  organization_id      uuid NOT NULL,
  name                 character varying(100) NOT NULL,

  created_at           timestamp,
  updated_at           timestamp,

  PRIMARY KEY (organization_id, name)
);

CREATE INDEX uix_agent_types_orgs ON agent_types USING btree (organization_id);

commit;
