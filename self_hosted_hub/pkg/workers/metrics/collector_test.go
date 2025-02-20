package metrics

import (
	"testing"

	"github.com/semaphoreio/semaphore/self_hosted_hub/pkg/database"
	"github.com/semaphoreio/semaphore/self_hosted_hub/pkg/models"
	"github.com/stretchr/testify/assert"
)

func Test__AgentsInState(t *testing.T) {
	database.TruncateTables()
	requesterID := database.UUID()
	firstOrgID := database.UUID()
	secondOrgID := database.UUID()

	// first org has 3 agents (2 busy, 1 idle)
	models.CreateAgentType(firstOrgID, &requesterID, "s1-first")
	models.CreateAgentType(firstOrgID, &requesterID, "s1-second")
	models.RegisterAgent(firstOrgID, "s1-first", "hello", models.AgentMetadata{})
	b1, _, _ := models.RegisterAgent(firstOrgID, "s1-first", "hello2", models.AgentMetadata{})
	b2, _, _ := models.RegisterAgent(firstOrgID, "s1-second", "hello5", models.AgentMetadata{})
	models.ForcefullyOccupyAgentWithJobID(b1)
	models.ForcefullyOccupyAgentWithJobID(b2)

	// second org has only 1 busy agent
	models.CreateAgentType(secondOrgID, &requesterID, "s1-first")
	b3, _, _ := models.RegisterAgent(secondOrgID, "s1-first", "hello", models.AgentMetadata{})
	models.ForcefullyOccupyAgentWithJobID(b3)

	collector := NewCollector()
	counts, err := collector.CountAgentsInState()
	assert.NoError(t, err)
	assert.Equal(t, models.AgentsInState{
		Busy: 3,
		Idle: 1,
	}, *counts)
}

func Test__AgentsInVersion(t *testing.T) {
	database.TruncateTables()
	firstOrgID := database.UUID()
	secondOrgID := database.UUID()
	requesterID := database.UUID()

	// first org has 5 agents total
	// 2.1.12 => 3
	// 2.1.11 => 1
	// 2.0.2  => 1
	models.CreateAgentType(firstOrgID, &requesterID, "s1-first")
	models.RegisterAgent(firstOrgID, "s1-first", "hello", models.AgentMetadata{Version: "2.1.12"})
	models.RegisterAgent(firstOrgID, "s1-first", "hello2", models.AgentMetadata{Version: "2.1.12"})
	models.RegisterAgent(firstOrgID, "s1-first", "hello3", models.AgentMetadata{Version: "2.1.11"})
	models.CreateAgentType(firstOrgID, &requesterID, "s1-second")
	models.RegisterAgent(firstOrgID, "s1-second", "hello5", models.AgentMetadata{Version: "2.1.12"})
	models.RegisterAgent(firstOrgID, "s1-second", "hello6", models.AgentMetadata{Version: "2.0.2"})

	// second org has only 1 agent, 2.1.11
	models.CreateAgentType(secondOrgID, &requesterID, "s1-first")
	models.RegisterAgent(secondOrgID, "s1-first", "hello", models.AgentMetadata{Version: "2.1.11"})

	collector := NewCollector()
	counts, err := collector.CountAgentsInVersion()
	assert.NoError(t, err)
	assert.Equal(t, []AgentsInVersion{
		{
			Version: "2.1.12",
			Count:   3,
		},
		{
			Version: "2.1.11",
			Count:   2,
		},
		{
			Version: "2.0.2",
			Count:   1,
		},
	}, counts)
}
