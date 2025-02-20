begin;

CREATE UNIQUE INDEX uix_agent_name_in_orgs ON agents USING btree (organization_id, name);

commit;
