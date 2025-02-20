package models

import (
	"fmt"
	"testing"
	"time"

	database "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/database"
	securetoken "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/securetoken"
	require "github.com/stretchr/testify/require"
)

func Test__FindAgentByToken(t *testing.T) {
	database.TruncateTables()

	orgID := database.UUID()
	requesterID := database.UUID()

	_, _, err := CreateAgentType(orgID, &requesterID, "s1-test-1")
	require.Nil(t, err)

	_, accessToken, err := RegisterAgent(orgID, "s1-test-1", "hello", AgentMetadata{})
	require.Nil(t, err)

	at, err := FindAgentByToken(orgID.String(), securetoken.Hash(accessToken))
	require.Nil(t, err)
	require.NotNil(t, at)
}

func Test__RegisterAgent(t *testing.T) {
	database.TruncateTables()

	orgID := database.UUID()
	requesterID := database.UUID()

	_, _, err := CreateAgentType(orgID, &requesterID, "s1-test-1")
	require.Nil(t, err)

	t.Run("registering an agent", func(t *testing.T) {
		a, accessToken, err := RegisterAgent(orgID, "s1-test-1", "hello", AgentMetadata{})
		require.Nil(t, err)

		require.Equal(t, "hello", a.Name)
		require.Equal(t, orgID, a.OrganizationID)
		require.Equal(t, "s1-test-1", a.AgentTypeName)
		require.Len(t, accessToken, 80)
	})

	t.Run("repeated request with the same name regenerates the access token", func(t *testing.T) {
		a1, accessToken1, err := RegisterAgent(orgID, "s1-test-1", "hello-123", AgentMetadata{})
		require.Nil(t, err)

		a2, accessToken2, err := RegisterAgent(orgID, "s1-test-1", "hello-123", AgentMetadata{})
		require.Nil(t, err)

		require.Equal(t, "hello-123", a1.Name)
		require.Equal(t, orgID, a1.OrganizationID)
		require.Equal(t, "s1-test-1", a1.AgentTypeName)
		require.NotEqual(t, accessToken1, accessToken2)
		require.Equal(t, a1.ID, a2.ID)
	})

	t.Run("repeated request with the same name that arrives too late is not accepted", func(t *testing.T) {
		agent, _, err := RegisterAgent(orgID, "s1-test-1", "hello-456", AgentMetadata{})
		require.Nil(t, err)

		fiveMinAgo := time.Now().Add(-10 * time.Minute)
		agent.CreatedAt = &fiveMinAgo
		err = database.Conn().Save(agent).Error
		require.Nil(t, err)

		_, _, err = RegisterAgent(orgID, "s1-test-1", "hello-456", AgentMetadata{})
		require.NotNil(t, err)
		require.Equal(t, err, ErrAgentCantBeRegistered)
	})

	t.Run("repeated request with the same name that arrives after initial agent already synced fails", func(t *testing.T) {
		_, token, err := RegisterAgent(orgID, "s1-test-1", "hello-789", AgentMetadata{})
		require.Nil(t, err)

		_, err = SyncAgent(orgID.String(), securetoken.Hash(token), "waiting-for-jobs", "", 0)
		require.Nil(t, err)

		_, _, err = RegisterAgent(orgID, "s1-test-1", "hello-789", AgentMetadata{})
		require.NotNil(t, err)
		require.Equal(t, err, ErrAgentCantBeRegistered)
	})
}

func Test__ListAgentsWithCursor(t *testing.T) {
	database.TruncateTables()

	orgID := database.UUID()
	requesterID := database.UUID()

	_, _, err := CreateAgentType(orgID, &requesterID, "s1-test-1")
	require.Nil(t, err)

	for i := 0; i < 150; i++ {
		_, _, err = RegisterAgent(orgID, "s1-test-1", fmt.Sprintf("hello%d", i), AgentMetadata{})
		require.Nil(t, err)
		time.Sleep(5 * time.Millisecond)
	}

	// first "page"
	agents, next, err := ListAgentsWithCursor(orgID, "s1-test-1", 100, "")
	require.Nil(t, err)
	require.Len(t, agents, 100)
	require.NotEmpty(t, next)

	// second "page"
	agents, next, err = ListAgentsWithCursor(orgID, "s1-test-1", 100, next)
	require.Nil(t, err)
	require.Len(t, agents, 50)
	require.Empty(t, next)
}

func Test__CountAgentsGroupedByAgentType(t *testing.T) {
	database.TruncateTables()

	orgID := database.UUID()
	requesterID := database.UUID()

	_, _, err := CreateAgentType(orgID, &requesterID, "s1-test-1")
	require.Nil(t, err)

	_, _, err = CreateAgentType(orgID, &requesterID, "s1-test-2")
	require.Nil(t, err)

	_, _, err = RegisterAgent(orgID, "s1-test-1", "hello1", AgentMetadata{})
	require.Nil(t, err)

	_, _, err = RegisterAgent(orgID, "s1-test-1", "hello2", AgentMetadata{})
	require.Nil(t, err)

	_, _, err = RegisterAgent(orgID, "s1-test-2", "hello3", AgentMetadata{})
	require.Nil(t, err)

	counts, err := CountAgentsGroupedByAgentType(orgID)
	require.Nil(t, err)

	require.Equal(t, counts["s1-test-1"], 2)
	require.Equal(t, counts["s1-test-2"], 1)
}

func Test__OccupyAgent(t *testing.T) {
	database.TruncateTables()

	orgID := database.UUID()
	requesterID := database.UUID()

	_, _, err := CreateAgentType(orgID, &requesterID, "s1-test-1")
	require.Nil(t, err)

	agent, token, err := RegisterAgent(orgID, "s1-test-1", "hello1", AgentMetadata{})
	require.Nil(t, err)

	t.Run("if no occupation request exists => error", func(t *testing.T) {
		_, err := OccupyAgent(agent)
		require.Error(t, err)
	})

	t.Run("if occupation request exists => occupies", func(t *testing.T) {
		jobID := database.UUID()
		err := CreateOccupationRequest(orgID, "s1-test-1", jobID)
		require.NoError(t, err)

		assignedJobID, err := OccupyAgent(agent)
		require.NoError(t, err)
		require.Equal(t, jobID.String(), assignedJobID)

		// agent is updated
		agent, err := FindAgentByToken(orgID.String(), securetoken.Hash(token))
		require.NoError(t, err)
		require.NotNil(t, agent.JobAssignedAt)
		require.Equal(t, agent.AssignedJobID, &jobID)

		// occupation request is deleted
		req, err := FindOccupationRequest(orgID, "s1-test-1", jobID)
		require.Error(t, err)
		require.Nil(t, req)
	})
}

func Test__ReleaseAgent(t *testing.T) {
	database.TruncateTables()

	orgID := database.UUID()
	requesterID := database.UUID()

	_, _, err := CreateAgentType(orgID, &requesterID, "s1-test-1")
	require.Nil(t, err)

	a, _, err := RegisterAgent(orgID, "s1-test-1", "hello1", AgentMetadata{})
	require.Nil(t, err)
	jobID, _ := ForcefullyOccupyAgentWithJobID(a)

	agent, err := ReleaseAgent(orgID, "s1-test-1", jobID)
	require.Nil(t, err)
	require.Nil(t, agent.AssignedJobID)
	require.Nil(t, agent.JobStopRequestedAt)
	require.Nil(t, agent.JobAssignedAt)
}

func Test__DisableAgent(t *testing.T) {
	database.TruncateTables()

	orgID := database.UUID()
	requesterID := database.UUID()

	_, _, err := CreateAgentType(orgID, &requesterID, "s1-test-1")
	require.Nil(t, err)

	_, _, err = RegisterAgent(orgID, "s1-test-1", "hello1", AgentMetadata{})
	require.Nil(t, err)

	agent, err := DisableAgent(orgID, "s1-test-1", "hello1")
	now := time.Now()
	require.Nil(t, err)
	require.WithinDuration(t, now, *agent.DisabledAt, 100*time.Millisecond)
}

func Test__Disconnect(t *testing.T) {
	database.TruncateTables()

	orgID := database.UUID()
	requesterID := database.UUID()

	t.Run("removes record from the database", func(t *testing.T) {
		_, _, err := CreateAgentType(orgID, &requesterID, "s1-test-1")
		require.Nil(t, err)

		agent, _, err := RegisterAgent(orgID, "s1-test-1", "hello1", AgentMetadata{})
		require.Nil(t, err)

		err = agent.Disconnect()
		require.Nil(t, err)

		_, err = FindAgentByToken(orgID.String(), agent.TokenHash)
		require.Equal(t, err.Error(), "record not found")
	})

	t.Run("changes record state", func(t *testing.T) {
		_, _, err := CreateAgentTypeWithSettings(
			orgID, &requesterID, "s1-test-2", AgentNameSettings{ReleaseNameAfter: 1},
		)

		require.NoError(t, err)

		agent, _, err := RegisterAgent(orgID, "s1-test-2", "hello1", AgentMetadata{})
		require.NoError(t, err)

		err = agent.Disconnect()
		require.NoError(t, err)

		agent, err = FindAgentByToken(orgID.String(), agent.TokenHash)
		require.NoError(t, err)
		require.Equal(t, agent.State, AgentStateDisconnected)
	})
}

func Test__StopJob(t *testing.T) {
	database.TruncateTables()

	orgID := database.UUID()
	requesterID := database.UUID()

	_, _, err := CreateAgentType(orgID, &requesterID, "s1-test-1")
	require.Nil(t, err)

	agent, token, err := RegisterAgent(orgID, "s1-test-1", "hello1", AgentMetadata{})
	require.Nil(t, err)

	t.Run("no occupation request and no assigned agent", func(t *testing.T) {
		err = StopJob(orgID, database.UUID())
		require.Error(t, err)

		agent, err := FindAgentByToken(orgID.String(), securetoken.Hash(token))
		require.NoError(t, err)
		require.Nil(t, agent.JobStopRequestedAt)
	})

	t.Run("deletes occupation request", func(t *testing.T) {
		jobID := database.UUID()
		CreateOccupationRequest(orgID, "s1-test-1", jobID)

		err = StopJob(orgID, jobID)
		require.NoError(t, err)

		req, err := FindOccupationRequest(orgID, "s1-test-1", jobID)
		require.Error(t, err)
		require.Nil(t, req)
	})

	t.Run("updates agent timestamp", func(t *testing.T) {
		jobID, _ := ForcefullyOccupyAgentWithJobID(agent)
		err = StopJob(orgID, jobID)
		require.Nil(t, err)

		now := time.Now()
		agent, err := FindAgentByToken(orgID.String(), securetoken.Hash(token))
		require.NoError(t, err)
		require.WithinDuration(t, now, *agent.JobStopRequestedAt, 100*time.Millisecond)
	})
}
