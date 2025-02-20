package agentcounter

import (
	"testing"
	"time"

	"github.com/semaphoreio/semaphore/self_hosted_hub/pkg/database"
	"github.com/semaphoreio/semaphore/self_hosted_hub/pkg/models"
	"github.com/stretchr/testify/assert"
)

func Test__AgentCounter(t *testing.T) {
	database.TruncateTables()
	requesterID := database.UUID()
	firstOrgID := database.UUID()
	secondOrgID := database.UUID()
	thirdOrgID := database.UUID()

	// first org has 6 agents total
	models.CreateAgentType(firstOrgID, &requesterID, "s1-first")
	a1, _, _ := models.RegisterAgent(firstOrgID, "s1-first", "hello", models.AgentMetadata{})
	a2, _, _ := models.RegisterAgent(firstOrgID, "s1-first", "hello2", models.AgentMetadata{})
	a3, _, _ := models.RegisterAgent(firstOrgID, "s1-first", "hello3", models.AgentMetadata{})
	models.RegisterAgent(firstOrgID, "s1-first", "hello4", models.AgentMetadata{})
	models.CreateAgentType(firstOrgID, &requesterID, "s1-second")
	models.RegisterAgent(firstOrgID, "s1-second", "hello5", models.AgentMetadata{})
	models.RegisterAgent(firstOrgID, "s1-second", "hello6", models.AgentMetadata{})

	// second org has only 1 agent
	models.CreateAgentType(secondOrgID, &requesterID, "s1-first")
	models.RegisterAgent(secondOrgID, "s1-first", "hello", models.AgentMetadata{})

	interval := 100 * time.Millisecond
	counter, _ := NewAgentCounter(&interval)
	assert.Equal(t, 0, counter.Get(firstOrgID.String()))
	assert.Equal(t, 0, counter.Get(secondOrgID.String()))
	assert.Equal(t, 0, counter.Get(thirdOrgID.String()))
	go counter.Start()

	// Wait for the counter to tick and assert values are correct
	time.Sleep(2 * interval)
	assert.Equal(t, 6, counter.Get(firstOrgID.String()))
	assert.Equal(t, 1, counter.Get(secondOrgID.String()))
	assert.Equal(t, 0, counter.Get(thirdOrgID.String()))

	// New agents registered and some disconnected
	models.RegisterAgent(secondOrgID, "s1-first", "hello2", models.AgentMetadata{})
	models.RegisterAgent(secondOrgID, "s1-first", "hello3", models.AgentMetadata{})
	models.RegisterAgent(secondOrgID, "s1-first", "hello4", models.AgentMetadata{})
	models.RegisterAgent(thirdOrgID, "s1-first", "hello", models.AgentMetadata{})
	models.RegisterAgent(thirdOrgID, "s1-first", "hello2", models.AgentMetadata{})
	assert.NoError(t, a1.Disconnect())
	assert.NoError(t, a2.Disconnect())
	assert.NoError(t, a3.Disconnect())

	// Wait for the counter to tick and assert values are correct
	time.Sleep(2 * interval)
	assert.Equal(t, 3, counter.Get(firstOrgID.String()))
	assert.Equal(t, 4, counter.Get(secondOrgID.String()))
	assert.Equal(t, 0, counter.Get(thirdOrgID.String()))
	assert.Equal(t, 0, counter.Get(database.UUID().String()))
}
