-- Single statement, no transaction: CREATE INDEX CONCURRENTLY cannot run inside one.
CREATE INDEX CONCURRENTLY IF NOT EXISTS index_agents_on_org_and_state ON agents (organization_id, state);
