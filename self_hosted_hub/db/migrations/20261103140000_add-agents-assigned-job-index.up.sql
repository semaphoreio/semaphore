-- Single statement, no transaction: CREATE INDEX CONCURRENTLY cannot run inside one.
CREATE INDEX CONCURRENTLY IF NOT EXISTS index_agents_on_org_and_assigned_job_id ON agents (organization_id, assigned_job_id) WHERE assigned_job_id IS NOT NULL;
