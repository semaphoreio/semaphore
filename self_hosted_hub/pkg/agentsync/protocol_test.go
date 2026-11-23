package agentsync

import (
	"context"
	"errors"
	"testing"

	"github.com/semaphoreio/semaphore/self_hosted_hub/pkg/amqp"
	database "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/database"
	models "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/models"
	"github.com/stretchr/testify/require"
	"gorm.io/gorm"
)

func Test__FinishedJobMark(t *testing.T) {
	database.TruncateTables()

	publisher, err := amqp.NewPublisher("amqp://guest:guest@rabbitmq:5672")
	require.NoError(t, err)

	orgID := database.UUID()
	requesterID := database.UUID()

	_, _, err = models.CreateAgentTypeWithSettings(
		orgID, &requesterID, "s1-test", models.AgentNameSettings{ReleaseNameAfter: 60},
	)
	require.NoError(t, err)

	finishJob := func(ctx context.Context, t *testing.T, name string, singleJob bool) (*models.Agent, error) {
		agent, _, err := models.RegisterAgent(orgID, "s1-test", name, models.AgentMetadata{SingleJob: singleJob})
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
		agent, err := finishJob(context.Background(), t, "published", true)

		require.NoError(t, err)
		require.Nil(t, agent.AssignedJobID)
	})

	t.Run("disconnect keeps the job when the finished callback was not published", func(t *testing.T) {
		ctx, cancel := context.WithCancel(context.Background())
		cancel()

		agent, err := finishJob(ctx, t, "not-published", true)

		require.Error(t, err)
		require.NotNil(t, agent.AssignedJobID)
		require.Nil(t, agent.JobFinishedAt)
	})

	t.Run("the sync fails when the job cannot be marked as finished", func(t *testing.T) {
		callback := "test:fail_job_finished_mark"
		err := database.Conn().Callback().Update().Before("gorm:update").Register(callback, func(tx *gorm.DB) {
			if updates, ok := tx.Statement.Dest.(map[string]interface{}); ok {
				if _, marking := updates["job_finished_at"]; marking {
					_ = tx.AddError(errors.New("marking failed"))
				}
			}
		})
		require.NoError(t, err)
		defer func() { _ = database.Conn().Callback().Update().Remove(callback) }()

		agent, err := finishJob(context.Background(), t, "not-marked", true)

		require.ErrorContains(t, err, "marking failed")
		require.NotNil(t, agent.AssignedJobID)
		require.Nil(t, agent.JobFinishedAt)
	})

	t.Run("an agent that takes more jobs is released and not marked", func(t *testing.T) {
		agent, err := finishJob(context.Background(), t, "multi-job", false)

		require.NoError(t, err)
		require.Nil(t, agent.AssignedJobID)
		require.Nil(t, agent.JobFinishedAt)
	})
}
