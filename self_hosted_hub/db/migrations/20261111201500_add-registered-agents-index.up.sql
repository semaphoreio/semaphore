CREATE INDEX CONCURRENTLY IF NOT EXISTS ix_agents_registered_org_type ON agents USING btree (organization_id, agent_type_name) WHERE state = 'registered';
