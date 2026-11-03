package database

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func Test__AgentsIndexes(t *testing.T) {
	expected := map[string][]string{
		"index_agents_on_org_and_assigned_job_id":        {"organization_id", "assigned_job_id", "WHERE (assigned_job_id IS NOT NULL)"},
		"index_agents_on_org_and_state":                  {"organization_id", "state"},
		"index_agents_on_organization_id_and_token_hash": {"organization_id", "token_hash"},
	}

	for name, parts := range expected {
		var def string
		err := Conn().Raw(
			"SELECT indexdef FROM pg_indexes WHERE tablename = 'agents' AND indexname = ?", name,
		).Scan(&def).Error

		require.NoError(t, err)
		require.NotEmpty(t, def, "index %s is missing", name)

		for _, part := range parts {
			assert.Contains(t, def, part)
		}
	}
}
