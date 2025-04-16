package workers

import (
	"testing"

	"github.com/google/uuid"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/database"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/models"
	protos "github.com/semaphoreio/semaphore/delivery-hub/pkg/protos/delivery"
	"github.com/semaphoreio/semaphore/delivery-hub/test/grpcmock"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func Test__PendingExecutionsWorker(t *testing.T) {
	require.NoError(t, database.TruncateTables())

	mockRegistry, err := grpcmock.Start()
	require.NoError(t, err)

	org := uuid.New()
	user := uuid.New()

	canvas, err := models.CreateCanvas(org, "test")
	require.NoError(t, err)

	source, err := canvas.CreateEventSource("gh", []byte("my-key"))
	require.NoError(t, err)

	w := PendingExecutionsWorker{
		RepoProxyURL: "0.0.0.0:50052",
	}

	t.Run("semaphore workflow is created", func(t *testing.T) {
		//
		// Create stage that creates Semaphore workflows.
		//
		template := models.RunTemplate{
			Type: protos.RunTemplate_TYPE_SEMAPHORE_WORKFLOW.String(),
			SemaphoreWorkflow: &models.SemaphoreWorkflowTemplate{
				Project:      "demo-project",
				Branch:       "main",
				PipelineFile: ".semaphore/run.yml",
			},
		}

		require.NoError(t, canvas.CreateStage("stage-1", user, false, template, []models.StageConnection{
			{
				SourceID:   source.ID,
				SourceType: models.SourceTypeEventSource,
			},
		}))

		stage, err := models.FindStageByName(org, canvas.ID, "stage-1")
		require.NoError(t, err)

		//
		// Create pending execution.
		//
		event, err := models.CreateStageEvent(stage.ID, source.ID)
		require.NoError(t, err)
		execution, err := models.CreateStageExecution(stage.ID, event.ID)
		require.NoError(t, err)

		//
		// Trigger the worker, and verify that request to repo proxy was sent,
		// and that execution was moved to 'started' state.
		//
		err = w.Tick()
		require.NoError(t, err)
		execution, err = stage.FindExecutionByID(execution.ID)
		require.NoError(t, err)
		assert.Equal(t, models.StageExecutionStarted, execution.State)
		assert.NotEmpty(t, execution.ReferenceID)
		assert.NotEmpty(t, execution.StartedAt)
		repoProxyReq := mockRegistry.RepoProxyService.GetLastCreateRequest()
		require.NotNil(t, repoProxyReq)
		assert.Equal(t, "demo-project", repoProxyReq.ProjectId)
		assert.Equal(t, ".semaphore/run.yml", repoProxyReq.DefinitionFile)
		assert.Equal(t, stage.CreatedBy.String(), repoProxyReq.RequesterId)
		assert.Equal(t, "refs/heads/main", repoProxyReq.Git.Reference)
	})
}
