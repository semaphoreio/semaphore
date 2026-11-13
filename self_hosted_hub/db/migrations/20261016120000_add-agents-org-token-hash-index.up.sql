CREATE INDEX CONCURRENTLY IF NOT EXISTS index_agents_on_organization_id_and_token_hash ON agents (organization_id, token_hash);
