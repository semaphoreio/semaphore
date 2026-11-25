package agentcleaner

import (
	"context"
	"errors"
	"fmt"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/semaphoreio/semaphore/self_hosted_hub/pkg/amqp"
	database "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/database"
	models "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/models"
	"github.com/sirupsen/logrus"
	logrustest "github.com/sirupsen/logrus/hooks/test"
	"github.com/stretchr/testify/require"
)

var orgID = database.UUID()
var requesterID = database.UUID()
var publisher, _ = amqp.NewPublisher("amqp://guest:guest@rabbitmq:5672")

func Test__DeletingStuckAgents(t *testing.T) {
	database.TruncateTables()

	at := createAgentType(t, "s1-hello")

	t.Run("it doesn't delete agents that didn't sync at all up to 1m after registring", func(t *testing.T) {
		agent := createAgent(t, at.Name)
		Tick(publisher)
		assertAgentExists(t, agent.ID.String())
	})

	t.Run("it deletes agents that didn't sync at all 1m after registering", func(t *testing.T) {
		agent := createAgent(t, at.Name)
		when := time.Now().Add(-2 * time.Minute)
		agent.CreatedAt = &when
		updateAgent(t, agent)

		Tick(publisher)

		assertAgentDoesntExists(t, agent.ID.String())
	})

	t.Run("it doesn't delete agents that synces in the last 3 minutes", func(t *testing.T) {
		when := time.Now().Add(-1 * time.Minute)

		agent := createAgent(t, at.Name)
		agent.LastSyncAt = &when
		updateAgent(t, agent)

		Tick(publisher)

		assertAgentExists(t, agent.ID.String())
	})

	t.Run("it deletes agents that haven't synced in the last 3 minutes", func(t *testing.T) {
		when := time.Now().Add(-5 * time.Minute)
		agent := createAgent(t, at.Name)
		agent.LastSyncAt = &when
		updateAgent(t, agent)

		Tick(publisher)

		assertAgentDoesntExists(t, agent.ID.String())
	})

	t.Run("it doesn't delete agents that have assigned jobs if below larger threshold", func(t *testing.T) {
		when := time.Now().Add(-5 * time.Minute)
		job := database.UUID()

		agent := createAgent(t, at.Name)
		agent.LastSyncAt = &when
		agent.AssignedJobID = &job
		updateAgent(t, agent)

		Tick(publisher)

		assertAgentExists(t, agent.ID.String())
	})

	t.Run("it deletes agents with assigned job id that haven't synced in the last 15 minutes", func(t *testing.T) {
		when := time.Now().Add(-20 * time.Minute)
		job := database.UUID()

		agent := createAgent(t, at.Name)
		agent.LastSyncAt = &when
		agent.AssignedJobID = &job
		updateAgent(t, agent)

		Tick(publisher)

		assertAgentDoesntExists(t, agent.ID.String())
	})

	t.Run("it doesn't delete disconnected agents that have no assigned job", func(t *testing.T) {
		when := time.Now().Add(-20 * time.Minute)

		agent := createAgent(t, at.Name)
		agent.LastSyncAt = &when
		agent.State = models.AgentStateDisconnected
		updateAgent(t, agent)

		Tick(publisher)

		assertAgentExists(t, agent.ID.String())
	})

	t.Run("it deletes disconnected agents that still have an assigned job", func(t *testing.T) {
		when := time.Now().Add(-20 * time.Minute)
		job := database.UUID()

		agent := createAgent(t, at.Name)
		agent.LastSyncAt = &when
		agent.AssignedJobID = &job
		agent.State = models.AgentStateDisconnected
		updateAgent(t, agent)

		Tick(publisher)

		assertAgentDoesntExists(t, agent.ID.String())
	})

	t.Run("it deletes more than one batch of agents in a single tick", func(t *testing.T) {
		when := time.Now().Add(-5 * time.Minute)
		agents := []*models.Agent{}

		for i := 0; i < batchSize+1; i++ {
			agent := createAgent(t, at.Name)
			agent.LastSyncAt = &when
			updateAgent(t, agent)
			agents = append(agents, agent)
		}

		Tick(publisher)

		for _, agent := range agents {
			assertAgentDoesntExists(t, agent.ID.String())
		}
	})
}

type fakeFinisher struct {
	calls int
	err   error
}

func (f *fakeFinisher) HandleJobFinished(_ context.Context, _ string, _ string) error {
	f.calls++
	return f.err
}

func Test__FinishedJobsAreNotFinalizedAgain(t *testing.T) {
	database.TruncateTables()

	at := createAgentType(t, "s1-finished")
	when := time.Now().Add(-20 * time.Minute)
	job := database.UUID()

	agent := createAgent(t, at.Name)
	agent.LastSyncAt = &when
	agent.AssignedJobID = &job
	agent.JobFinishedAt = &when
	updateAgent(t, agent)

	finisher := &fakeFinisher{}
	Tick(finisher)

	assertAgentDoesntExists(t, agent.ID.String())
	require.Zero(t, finisher.calls)
}

func Test__OldestAgentsAreCleanedFirst(t *testing.T) {
	database.TruncateTables()

	at := createAgentType(t, "s1-oldest")
	createStuckAgents(t, at.Name, batchSize, nil)

	longAgo := time.Now().Add(-30 * time.Minute)
	oldest := createAgent(t, at.Name)
	oldest.LastSyncAt = &longAgo
	updateAgent(t, oldest)

	found, deleted, err := deleteStuckAgents(database.Conn(), &fakeFinisher{})

	require.NoError(t, err)
	require.Equal(t, batchSize, found)
	require.Equal(t, batchSize, deleted)
	assertAgentDoesntExists(t, oldest.ID.String())
}

func Test__TickStopsWhenNoAgentOfABatchIsDeleted(t *testing.T) {
	database.TruncateTables()

	at := createAgentType(t, "s1-failing")
	job := database.UUID()
	createStuckAgents(t, at.Name, batchSize, &job)

	finisher := &fakeFinisher{err: errors.New("publishing failed")}
	Tick(finisher)

	require.Equal(t, batchSize, finisher.calls)
	require.Equal(t, batchSize, countAgents(t))
}

func Test__FailingCallbacksDoNotHoldBackOtherAgents(t *testing.T) {
	database.TruncateTables()

	withJob := createAgentType(t, "s1-with-job")
	job := database.UUID()
	createStuckAgents(t, withJob.Name, batchSize, &job)

	longAgo := time.Now().Add(-40 * time.Minute)
	err := database.Conn().Model(&models.Agent{}).
		Where("agent_type_name = ?", withJob.Name).
		Update("last_sync_at", longAgo).Error
	require.NoError(t, err)

	idle := createAgentType(t, "s1-idle")
	createStuckAgents(t, idle.Name, batchSize/2, nil)

	Tick(&fakeFinisher{err: errors.New("publishing failed")})

	require.Equal(t, batchSize, countAgents(t))

	var idleLeft int64
	err = database.Conn().Model(&models.Agent{}).Where("agent_type_name = ?", idle.Name).Count(&idleLeft).Error
	require.NoError(t, err)
	require.Zero(t, idleLeft)
}

func Test__TickIsLimitedToAMaximumOfBatches(t *testing.T) {
	database.TruncateTables()

	at := createAgentType(t, "s1-backlog")
	createStuckAgents(t, at.Name, batchSize*maxBatchesPerTick+1, nil)

	hook := logrustest.NewGlobal()
	defer logrus.StandardLogger().ReplaceHooks(make(logrus.LevelHooks))

	Tick(&fakeFinisher{})

	require.Equal(t, 1, countAgents(t))
	require.Contains(t, hook.LastEntry().Message, "Reached the limit of 10 batches")
}

func createStuckAgents(t *testing.T, agentTypeName string, count int, job *uuid.UUID) {
	for i := 0; i < count; i++ {
		createAgent(t, agentTypeName)
	}

	when := time.Now().Add(-20 * time.Minute)
	err := database.Conn().Model(&models.Agent{}).
		Where("agent_type_name = ?", agentTypeName).
		Updates(map[string]interface{}{"last_sync_at": when, "assigned_job_id": job}).Error
	require.NoError(t, err)
}

func countAgents(t *testing.T) int {
	var count int64
	require.NoError(t, database.Conn().Model(&models.Agent{}).Count(&count).Error)

	return int(count)
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
