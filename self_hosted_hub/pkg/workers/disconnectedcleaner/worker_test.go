package disconnectedcleaner

import (
	"fmt"
	"math/rand"
	"testing"
	"time"

	"github.com/semaphoreio/semaphore/self_hosted_hub/pkg/amqp"
	database "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/database"
	models "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/models"
	"github.com/stretchr/testify/require"
)

var orgID = database.UUID()
var requesterID = database.UUID()
var publisher, _ = amqp.NewPublisher("amqp://guest:guest@rabbitmq:5672")

func Test__DeletingDisconnectedAgents(t *testing.T) {
	database.TruncateTables()

	at, _, err := models.CreateAgentTypeWithSettings(
		orgID, &requesterID, "s1-test", models.AgentNameSettings{ReleaseNameAfter: 60},
	)

	require.Nil(t, err)

	t.Run("it doesn't delete agents that didn't disconnect", func(t *testing.T) {
		agent := createAgent(t, at.Name)
		Tick(publisher)
		assertAgentExists(t, agent.ID.String())
	})

	t.Run("it deletes disconnected agents eventually", func(t *testing.T) {
		agent1 := createAgent(t, at.Name)
		agent2 := createAgent(t, at.Name)
		agent3 := createAgent(t, at.Name)
		Tick(publisher)

		// agent 2 and 3 disconnects
		agent2.Disconnect()
		agent3.Disconnect()
		assertAgentExists(t, agent1.ID.String())
		assertAgentExists(t, agent2.ID.String())
		assertAgentExists(t, agent3.ID.String())

		// force 2 minutes to pass for agent 3
		twoMinsAgo := time.Now().Add(-2 * time.Minute)
		require.NoError(t, database.Conn().Model(&agent3).Update("disconnected_at", &twoMinsAgo).Error)
		Tick(publisher)

		assertAgentExists(t, agent1.ID.String())
		assertAgentExists(t, agent2.ID.String())
		assertAgentDoesntExists(t, agent3.ID.String())
	})
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
