begin;

CREATE TABLE agents (
  organization_id      uuid NOT NULL,
  agent_type_name      character varying(100) NOT NULL,
  name                 character varying(100) NOT NULL,

  created_at           timestamp,
  updated_at           timestamp,
  last_hearthbeat_at   timestamp,

  PRIMARY KEY (organization_id, name)
);

CREATE INDEX uix_agent_orgs ON agents USING btree (organization_id, agent_type_name);

commit;
