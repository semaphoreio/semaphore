package agentsync

import (
	"context"
	"testing"

	"github.com/semaphoreio/semaphore/self_hosted_hub/pkg/amqp"
	database "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/database"
	models "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/models"
	"github.com/stretchr/testify/require"
)

func Test__FinishedJobOfSingleJobAgent(t *testing.T) {
	database.TruncateTables()

	publisher, err := amqp.NewPublisher("amqp://guest:guest@rabbitmq:5672")
	require.NoError(t, err)

	orgID := database.UUID()
	requesterID := database.UUID()

	_, _, err = models.CreateAgentTypeWithSettings(
		orgID, &requesterID, "s1-test", models.AgentNameSettings{ReleaseNameAfter: 60},
	)
	require.NoError(t, err)

	finishJob := func(ctx context.Context, t *testing.T, name string) (*models.Agent, error) {
		agent, _, err := models.RegisterAgent(orgID, "s1-test", name, models.AgentMetadata{SingleJob: true})
		require.NoError(t, err)

		jobID, err := models.ForcefullyOccupyAgentWithJobID(agent)
		require.NoError(t, err)

		agent, err = models.SyncAgent(orgID.String(), agent.TokenHash, AgentStateFinishedJob, jobID.String(), 0)
		require.NoError(t, err)

		_, finishErr := handleFinishedJobState(ctx, publisher, agent, jobID.String(), JobResultPassed)
		require.NoError(t, agent.Disconnect())

		agent, err = models.FindAgentByToken(orgID.String(), agent.TokenHash)
		require.NoError(t, err)

		return agent, finishErr
	}

	t.Run("disconnect clears the job when the finished callback was published", func(t *testing.T) {
		agent, err := finishJob(context.Background(), t, "published")

		require.NoError(t, err)
		require.Nil(t, agent.AssignedJobID)
	})

	t.Run("disconnect keeps the job when the finished callback was not published", func(t *testing.T) {
		ctx, cancel := context.WithCancel(context.Background())
		cancel()

		agent, err := finishJob(ctx, t, "not-published")

		require.Error(t, err)
		require.NotNil(t, agent.AssignedJobID)
		require.Nil(t, agent.JobFinishedAt)
	})
}
