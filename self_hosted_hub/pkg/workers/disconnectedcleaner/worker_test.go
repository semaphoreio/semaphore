package disconnectedcleaner

import (
	"fmt"
	"math/rand"
	"testing"
	"time"

	database "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/database"
	models "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/models"
	"github.com/sirupsen/logrus"
	logrustest "github.com/sirupsen/logrus/hooks/test"
	"github.com/stretchr/testify/require"
)

var orgID = database.UUID()
var requesterID = database.UUID()

func Test__DeletingDisconnectedAgents(t *testing.T) {
	database.TruncateTables()

	at, _, err := models.CreateAgentTypeWithSettings(
		orgID, &requesterID, "s1-test", models.AgentNameSettings{ReleaseNameAfter: 60},
	)

	require.Nil(t, err)

	t.Run("it doesn't delete agents that didn't disconnect", func(t *testing.T) {
		agent := createAgent(t, at.Name)
		Tick()
		assertAgentExists(t, agent.ID.String())
	})

	t.Run("it deletes disconnected agents eventually", func(t *testing.T) {
		agent1 := createAgent(t, at.Name)
		agent2 := createAgent(t, at.Name)
		agent3 := createAgent(t, at.Name)
		Tick()

		// agent 2 and 3 disconnects
		agent2.Disconnect()
		agent3.Disconnect()
		assertAgentExists(t, agent1.ID.String())
		assertAgentExists(t, agent2.ID.String())
		assertAgentExists(t, agent3.ID.String())

		// force 2 minutes to pass for agent 3
		twoMinsAgo := time.Now().Add(-2 * time.Minute)
		require.NoError(t, database.Conn().Model(&agent3).Update("disconnected_at", &twoMinsAgo).Error)
		Tick()

		assertAgentExists(t, agent1.ID.String())
		assertAgentExists(t, agent2.ID.String())
		assertAgentDoesntExists(t, agent3.ID.String())
	})
}

func Test__DisconnectedAgentsHoldingAJobAreKept(t *testing.T) {
	database.TruncateTables()

	at, _, err := models.CreateAgentTypeWithSettings(
		orgID, &requesterID, "s1-with-job", models.AgentNameSettings{ReleaseNameAfter: 60},
	)
	require.NoError(t, err)

	agent := createAgent(t, at.Name)
	_, err = models.ForcefullyOccupyAgentWithJobID(agent)
	require.NoError(t, err)
	require.NoError(t, agent.Disconnect())

	twoMinsAgo := time.Now().Add(-2 * time.Minute)
	require.NoError(t, database.Conn().Model(&agent).Update("disconnected_at", &twoMinsAgo).Error)

	Tick()

	assertAgentExists(t, agent.ID.String())
}

func Test__DeletingManyDisconnectedAgents(t *testing.T) {
	agentType := "s1-many"

	disconnect := func(t *testing.T, count int, when time.Time) {
		database.TruncateTables()
		_, _, err := models.CreateAgentTypeWithSettings(
			orgID, &requesterID, agentType, models.AgentNameSettings{ReleaseNameAfter: 60},
		)
		require.NoError(t, err)

		for i := 0; i < count; i++ {
			createAgent(t, agentType)
		}

		err = database.Conn().Model(&models.Agent{}).
			Where("agent_type_name = ?", agentType).
			Updates(map[string]interface{}{"state": models.AgentStateDisconnected, "disconnected_at": when}).Error
		require.NoError(t, err)
	}

	twoMinsAgo := time.Now().Add(-2 * time.Minute)

	t.Run("it deletes more than one batch in a single tick", func(t *testing.T) {
		disconnect(t, batchSize*2+50, twoMinsAgo)

		Tick()

		require.Zero(t, countAgents(t))
	})

	t.Run("it stops at the limit of batches and warns", func(t *testing.T) {
		disconnect(t, batchSize*maxBatchesPerTick+1, twoMinsAgo)

		hook := logrustest.NewGlobal()
		defer logrus.StandardLogger().ReplaceHooks(make(logrus.LevelHooks))

		Tick()

		require.Equal(t, 1, countAgents(t))
		require.Contains(t, hook.LastEntry().Message, "Reached the limit of 10 batches")
	})

	t.Run("it deletes the agents disconnected the longest first", func(t *testing.T) {
		disconnect(t, batchSize, twoMinsAgo)

		oldest := createAgent(t, agentType)
		tenMinsAgo := time.Now().Add(-10 * time.Minute)
		err := database.Conn().Model(&oldest).
			Updates(map[string]interface{}{"state": models.AgentStateDisconnected, "disconnected_at": tenMinsAgo}).Error
		require.NoError(t, err)

		deleted, err := deleteDisconnectedAgents(database.Conn())

		require.NoError(t, err)
		require.Equal(t, batchSize, deleted)
		assertAgentDoesntExists(t, oldest.ID.String())
	})
}

func countAgents(t *testing.T) int {
	var count int64
	require.NoError(t, database.Conn().Model(&models.Agent{}).Count(&count).Error)

	return int(count)
}

func createAgent(t *testing.T, agentTypeName string) *models.Agent {
	name := fmt.Sprintf("sh-%d", rand.Int())

	agent, _, err := models.RegisterAgent(orgID, agentTypeName, name, models.AgentMetadata{})
	require.Nil(t, err)

	return agent
}

func assertAgentExists(t *testing.T, id string) {
	err := database.Conn().Where("id = ?", id).First(&models.Agent{}).Error

	require.Nil(t, err)
}

func assertAgentDoesntExists(t *testing.T, id string) {
	err := database.Conn().Where("id = ?", id).First(&models.Agent{}).Error

	require.NotNil(t, err)
	require.Equal(t, err.Error(), "record not found")
}
