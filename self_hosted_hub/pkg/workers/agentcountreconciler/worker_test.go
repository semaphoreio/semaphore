package agentcountreconciler

import (
	"testing"

	database "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/database"
	models "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/models"
	require "github.com/stretchr/testify/require"
)

func Test__Tick(t *testing.T) {
	database.TruncateTables()

	orgID := database.UUID()
	requesterID := database.UUID()

	_, _, err := models.CreateAgentType(orgID, &requesterID, "s1-reconciler")
	require.NoError(t, err)

	_, _, err = models.RegisterAgent(orgID, "s1-reconciler", "reconciler-1", models.AgentMetadata{})
	require.NoError(t, err)
	_, _, err = models.RegisterAgent(orgID, "s1-reconciler", "reconciler-2", models.AgentMetadata{})
	require.NoError(t, err)

	t.Run("keeps correct counts", func(t *testing.T) {
		Tick()
		requireStoredCount(t, orgID.String(), 2)
	})

	t.Run("fixes counts that drifted", func(t *testing.T) {
		require.NoError(t, database.Conn().Exec(`UPDATE agent_counts SET registered = 7 WHERE organization_id = ?`, orgID).Error)
		Tick()
		requireStoredCount(t, orgID.String(), 2)
	})
}

func requireStoredCount(t *testing.T, orgID string, expected int) {
	var stored int
	require.NoError(t, database.Conn().Raw(`SELECT registered FROM agent_counts WHERE organization_id = ?`, orgID).Row().Scan(&stored))
	require.Equal(t, expected, stored)
}
