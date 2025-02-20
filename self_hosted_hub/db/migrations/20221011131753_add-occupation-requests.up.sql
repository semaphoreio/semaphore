begin;

CREATE TABLE occupation_requests (
  organization_id      uuid NOT NULL,
  agent_type_name      character varying(100) NOT NULL,
  job_id               uuid NOT NULL,
  created_at           timestamp,

  PRIMARY KEY (organization_id, agent_type_name, job_id),
  FOREIGN KEY (organization_id, agent_type_name) REFERENCES agent_types(organization_id, name)
);

CREATE INDEX uix_occupation_req_org_type ON agents USING btree (organization_id, agent_type_name);

commit;
