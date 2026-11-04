package models

import (
	"context"
	"fmt"
	"os"
	"testing"
	"time"

	uuid "github.com/google/uuid"
	database "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/database"
	require "github.com/stretchr/testify/require"
	postgres "gorm.io/driver/postgres"
	gorm "gorm.io/gorm"
)

func Test__AgentCountsFollowAgentChanges(t *testing.T) {
	database.TruncateTables()

	orgID := database.UUID()
	otherOrgID := database.UUID()
	requesterID := database.UUID()

	_, _, err := CreateAgentType(orgID, &requesterID, "s1-delete")
	require.NoError(t, err)
	_, _, err = CreateAgentTypeWithSettings(orgID, &requesterID, "s1-keep-name", AgentNameSettings{ReleaseNameAfter: 60})
	require.NoError(t, err)
	_, _, err = CreateAgentType(otherOrgID, &requesterID, "s1-other")
	require.NoError(t, err)

	t.Run("organizations without agents have no count", func(t *testing.T) {
		requireAgentCount(t, orgID, 0)
	})

	t.Run("registering increments only the agent's organization", func(t *testing.T) {
		_, _, err := RegisterAgent(orgID, "s1-delete", "count-1", AgentMetadata{})
		require.NoError(t, err)
		_, _, err = RegisterAgent(orgID, "s1-keep-name", "count-2", AgentMetadata{})
		require.NoError(t, err)
		_, _, err = RegisterAgent(otherOrgID, "s1-other", "count-other-1", AgentMetadata{})
		require.NoError(t, err)

		requireAgentCount(t, orgID, 2)
		requireAgentCount(t, otherOrgID, 1)
	})

	t.Run("registration retry with the same name does not increment", func(t *testing.T) {
		_, _, err := RegisterAgent(orgID, "s1-delete", "count-1", AgentMetadata{})
		require.NoError(t, err)
		requireAgentCount(t, orgID, 2)
	})

	t.Run("a failed registration does not increment", func(t *testing.T) {
		_, _, err := RegisterAgent(orgID, "s1-does-not-exist", "count-fk", AgentMetadata{})
		require.Error(t, err)
		requireAgentCount(t, orgID, 2)
	})

	t.Run("syncing, occupying, releasing, stopping and disabling do not change the count", func(t *testing.T) {
		agent, _, err := RegisterAgent(orgID, "s1-delete", "count-busy", AgentMetadata{})
		require.NoError(t, err)
		requireAgentCount(t, orgID, 3)

		_, err = SyncAgent(orgID.String(), agent.TokenHash, "waiting-for-jobs", "", 0)
		require.NoError(t, err)

		jobID := database.UUID()
		require.NoError(t, CreateOccupationRequest(orgID, "s1-delete", jobID))
		_, err = OccupyAgent(agent)
		require.NoError(t, err)
		require.NoError(t, StopJob(orgID, jobID))
		_, err = ReleaseAgent(orgID, "s1-delete", jobID)
		require.NoError(t, err)

		_, err = DisableAgent(orgID, "s1-delete", "count-busy")
		require.NoError(t, err)
		require.NoError(t, DisableAllAgents(orgID, "s1-delete"))
		require.NoError(t, DisableOnlyIdleAgents(orgID, "s1-delete"))

		requireAgentCount(t, orgID, 3)

		// Disconnecting a disabled agent still decrements.
		require.NoError(t, agent.Disconnect())
		requireAgentCount(t, orgID, 2)
	})

	t.Run("disconnecting an agent that releases its name right away decrements", func(t *testing.T) {
		agent, _, err := RegisterAgent(orgID, "s1-delete", "count-disconnect-delete", AgentMetadata{})
		require.NoError(t, err)
		requireAgentCount(t, orgID, 3)

		require.NoError(t, agent.Disconnect())
		requireAgentCount(t, orgID, 2)
	})

	t.Run("disconnecting an agent that keeps its name decrements, and deleting it later does not", func(t *testing.T) {
		agent, _, err := RegisterAgent(orgID, "s1-keep-name", "count-disconnect-keep", AgentMetadata{})
		require.NoError(t, err)
		requireAgentCount(t, orgID, 3)

		require.NoError(t, agent.Disconnect())
		requireAgentCount(t, orgID, 2)

		// Disconnecting again (a retried request) does not decrement twice.
		require.NoError(t, agent.Disconnect())
		requireAgentCount(t, orgID, 2)

		// Same delete the disconnected agent cleaner runs.
		require.NoError(t, database.Conn().Delete(&Agent{}, "id = ?", agent.ID).Error)
		requireAgentCount(t, orgID, 2)
	})

	t.Run("deleting registered agents in bulk decrements each organization", func(t *testing.T) {
		a1, _, err := RegisterAgent(orgID, "s1-delete", "count-bulk-1", AgentMetadata{})
		require.NoError(t, err)
		a2, _, err := RegisterAgent(otherOrgID, "s1-other", "count-bulk-2", AgentMetadata{})
		require.NoError(t, err)
		requireAgentCount(t, orgID, 3)
		requireAgentCount(t, otherOrgID, 2)

		// Same delete the stuck agent cleaner runs.
		require.NoError(t, database.Conn().Where("id IN (?)", []string{a1.ID.String(), a2.ID.String()}).Delete(&Agent{}).Error)
		requireAgentCount(t, orgID, 2)
		requireAgentCount(t, otherOrgID, 1)
	})

	t.Run("deleting an agent type removes only disconnected agents and keeps the count", func(t *testing.T) {
		_, _, err := CreateAgentTypeWithSettings(orgID, &requesterID, "s1-to-delete", AgentNameSettings{ReleaseNameAfter: 60})
		require.NoError(t, err)

		agent, _, err := RegisterAgent(orgID, "s1-to-delete", "count-type-delete", AgentMetadata{})
		require.NoError(t, err)
		requireAgentCount(t, orgID, 3)

		at, err := FindAgentType(orgID, "s1-to-delete")
		require.NoError(t, err)

		// Registered agents block the deletion, nothing changes.
		require.ErrorIs(t, at.Delete(), ErrCantDeleteAgentTypeWithExistingAgents)
		requireAgentCount(t, orgID, 3)

		require.NoError(t, agent.Disconnect())
		requireAgentCount(t, orgID, 2)
		require.NoError(t, at.Delete())
		requireAgentCount(t, orgID, 2)
	})

	t.Run("a rolled back registration does not increment", func(t *testing.T) {
		tx := database.Conn().Begin()
		_, _, _, err := CreateAgentInTransaction(tx, orgID, "s1-delete", "count-rollback", AgentMetadata{})
		require.NoError(t, err)

		count, err := RegisteredAgentCountInTransaction(context.Background(), tx, orgID)
		require.NoError(t, err)
		require.Equal(t, 3, count)
		require.NoError(t, tx.Rollback().Error)

		requireAgentCount(t, orgID, 2)
	})
}

func Test__ReconcileAgentCounts(t *testing.T) {
	database.TruncateTables()

	orgID := database.UUID()
	staleOrgID := database.UUID()
	missingOrgID := database.UUID()
	correctOrgID := database.UUID()
	requesterID := database.UUID()

	for _, org := range []uuid.UUID{orgID, missingOrgID, correctOrgID} {
		_, _, err := CreateAgentType(org, &requesterID, "s1-reconcile")
		require.NoError(t, err)
	}

	for _, name := range []string{"r-1", "r-2", "r-3"} {
		_, _, err := RegisterAgent(orgID, "s1-reconcile", name, AgentMetadata{})
		require.NoError(t, err)
	}

	_, _, err := RegisterAgent(missingOrgID, "s1-reconcile", "r-missing", AgentMetadata{})
	require.NoError(t, err)
	_, _, err = RegisterAgent(correctOrgID, "s1-reconcile", "r-correct", AgentMetadata{})
	require.NoError(t, err)

	t.Run("nothing to fix when counts match", func(t *testing.T) {
		fixed, err := ReconcileAgentCounts(context.Background())
		require.NoError(t, err)
		require.Empty(t, fixed)
	})

	t.Run("fixes counts that drifted in either direction, or are missing", func(t *testing.T) {
		require.NoError(t, database.Conn().Exec(`UPDATE agent_counts SET registered = 10 WHERE organization_id = ?`, orgID).Error)
		require.NoError(t, database.Conn().Exec(`INSERT INTO agent_counts (organization_id, registered) VALUES (?, 4)`, staleOrgID).Error)
		require.NoError(t, database.Conn().Exec(`DELETE FROM agent_counts WHERE organization_id = ?`, missingOrgID).Error)

		fixed, err := ReconcileAgentCounts(context.Background())
		require.NoError(t, err)
		require.ElementsMatch(t, []AgentCountDrift{
			{OrganizationID: orgID, Counted: 3, Stored: 10},
			{OrganizationID: staleOrgID, Counted: 0, Stored: 4},
			{OrganizationID: missingOrgID, Counted: 1, Stored: 0},
		}, fixed)

		requireAgentCount(t, orgID, 3)
		requireAgentCount(t, staleOrgID, 0)
		requireAgentCount(t, missingOrgID, 1)
		requireAgentCount(t, correctOrgID, 1)

		fixed, err = ReconcileAgentCounts(context.Background())
		require.NoError(t, err)
		require.Empty(t, fixed)
	})

	t.Run("a registration that is in flight while reconciling is not lost", func(t *testing.T) {
		require.NoError(t, database.Conn().Exec(`UPDATE agent_counts SET registered = 0 WHERE organization_id = ?`, orgID).Error)

		// The registration is uncommitted, and runs in another database session:
		// its agent is not visible to the reconciliation count,
		// but its increment is applied after the reconciliation releases the counter row.
		tx := openExternalConnection(t).Begin()
		require.NoError(t, tx.Error)
		require.NoError(t, tx.Exec(
			"INSERT INTO agents (organization_id, agent_type_name, name, token_hash, state) VALUES (?, ?, ?, ?, ?)",
			orgID.String(), "s1-reconcile", "r-in-flight", "not-a-real-hash", AgentStateRegistered,
		).Error)

		done := make(chan error, 1)
		go func() {
			_, err := ReconcileAgentCounts(context.Background())
			done <- err
		}()

		// The reconciliation can't fix the row while the registration holds it.
		requireBlocked(t, done)

		require.NoError(t, tx.Commit().Error)
		require.NoError(t, <-done)

		requireAgentCount(t, orgID, 4)
	})
}

func requireAgentCount(t *testing.T, orgID uuid.UUID, expected int) {
	t.Helper()

	stored, err := RegisteredAgentCount(orgID)
	require.NoError(t, err)
	require.Equal(t, expected, stored, "stored agent count")

	counted, err := CountAgentsInOrganization(orgID.String())
	require.NoError(t, err)
	require.Equal(t, expected, counted, "agents in the table")
}

func requireBlocked(t *testing.T, done chan error) {
	t.Helper()

	select {
	case err := <-done:
		t.Fatalf("expected operation to be blocked, but it finished: %v", err)
	case <-time.After(300 * time.Millisecond):
	}
}

// A connection that does not share the application's connection pool,
// used to hold locks from a different database session.
func openExternalConnection(t *testing.T) *gorm.DB {
	dsn := fmt.Sprintf(
		"host=%s port=%s user=%s password=%s dbname=%s sslmode=disable",
		os.Getenv("DB_HOST"),
		os.Getenv("DB_PORT"),
		os.Getenv("DB_USERNAME"),
		os.Getenv("DB_PASSWORD"),
		os.Getenv("DB_NAME"),
	)

	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
	require.NoError(t, err)

	t.Cleanup(func() {
		if sqlDB, err := db.DB(); err == nil {
			_ = sqlDB.Close()
		}
	})

	return db
}
