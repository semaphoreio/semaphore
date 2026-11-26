CREATE INDEX IF NOT EXISTS uix_occupation_req_org_type ON agents USING btree (organization_id, agent_type_name);
