package agentcleaner

import (
	"fmt"
	"testing"
	"time"

	database "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/database"
	models "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/models"
	"github.com/stretchr/testify/require"
)

var orgID = database.UUID()
var requesterID = database.UUID()

func Test__DeletingStuckAgents(t *testing.T) {
	database.TruncateTables()

	at := createAgentType(t, "s1-hello")

	t.Run("it doesn't delete agents that didn't sync at all up to 1m after registring", func(t *testing.T) {
		agent := createAgent(t, at.Name)
		Tick()
		assertAgentExists(t, agent.ID.String())
	})

	t.Run("it deletes agents that didn't sync at all 1m after registering", func(t *testing.T) {
		agent := createAgent(t, at.Name)
		when := time.Now().Add(-2 * time.Minute)
		agent.CreatedAt = &when
		updateAgent(t, agent)

		Tick()

		assertAgentDoesntExists(t, agent.ID.String())
	})

	t.Run("it doesn't delete agents that synces in the last 3 minutes", func(t *testing.T) {
		when := time.Now().Add(-1 * time.Minute)

		agent := createAgent(t, at.Name)
		agent.LastSyncAt = &when
		updateAgent(t, agent)

		Tick()

		assertAgentExists(t, agent.ID.String())
	})

	t.Run("it deletes agents that haven't synced in the last 3 minutes", func(t *testing.T) {
		when := time.Now().Add(-5 * time.Minute)
		agent := createAgent(t, at.Name)
		agent.LastSyncAt = &when
		updateAgent(t, agent)

		Tick()

		assertAgentDoesntExists(t, agent.ID.String())
	})

	t.Run("it doesn't delete agents that have assigned jobs if below larger threshold", func(t *testing.T) {
		when := time.Now().Add(-5 * time.Minute)
		job := database.UUID()

		agent := createAgent(t, at.Name)
		agent.LastSyncAt = &when
		agent.AssignedJobID = &job
		updateAgent(t, agent)

		Tick()

		assertAgentExists(t, agent.ID.String())
	})

	t.Run("it deletes agents with assigned job id that haven't synced in the last 15 minutes", func(t *testing.T) {
		when := time.Now().Add(-20 * time.Minute)
		job := database.UUID()

		agent := createAgent(t, at.Name)
		agent.LastSyncAt = &when
		agent.AssignedJobID = &job
		updateAgent(t, agent)

		Tick()

		assertAgentDoesntExists(t, agent.ID.String())
	})
}

func createAgentType(t *testing.T, name string) *models.AgentType {
	at, _, err := models.CreateAgentType(orgID, &requesterID, name)
	require.Nil(t, err)

	return at
}

// Agent names must be unique in the organization.
// I'm achieving this by using a counter in the agent name.
var createAgentNumer = 0

func createAgent(t *testing.T, agentTypeName string) *models.Agent {
	createAgentNumer++
	name := fmt.Sprintf("sh-%d", createAgentNumer)

	agent, _, err := models.RegisterAgent(orgID, agentTypeName, name, models.AgentMetadata{})
	require.Nil(t, err)

	return agent
}

func updateAgent(t *testing.T, agent *models.Agent) {
	err := database.Conn().Save(agent).Error
	require.Nil(t, err)
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
