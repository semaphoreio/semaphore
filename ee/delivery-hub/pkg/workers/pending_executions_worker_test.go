package workers

import (
	"slices"
	"testing"

	"github.com/google/uuid"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/database"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/models"
	schedulepb "github.com/semaphoreio/semaphore/delivery-hub/pkg/protos/periodic_scheduler"
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
		SchedulerURL: "0.0.0.0:50052",
	}

	t.Run("semaphore workflow is created", func(t *testing.T) {
		//
		// Create stage that creates Semaphore workflows.
		//
		template := models.RunTemplate{
			Type: models.RunTemplateTypeSemaphoreWorkflow,
			SemaphoreWorkflow: &models.SemaphoreWorkflowTemplate{
				ProjectID:    "demo-project",
				Branch:       "main",
				PipelineFile: ".semaphore/run.yml",
			},
		}

		require.NoError(t, canvas.CreateStage("stage-wf", user, false, template, []models.StageConnection{
			{
				SourceID:   source.ID,
				SourceType: models.SourceTypeEventSource,
			},
		}))

		stage, err := models.FindStageByName(org, canvas.ID, "stage-wf")
		require.NoError(t, err)

		//
		// Create pending execution.
		//
		e, err := models.CreateEvent(source.ID, models.SourceTypeEventSource, []byte(`{}`))
		require.NoError(t, err)
		event, err := models.CreateStageEvent(stage.ID, e)
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

	t.Run("semaphore task is triggered", func(t *testing.T) {
		//
		// Create stage that trigger Semaphore task.
		//
		template := models.RunTemplate{
			Type: models.RunTemplateTypeSemaphoreTask,
			SemaphoreTask: &models.SemaphoreTaskTemplate{
				ProjectID:    "demo-project",
				TaskID:       "demo-task",
				Branch:       "main",
				PipelineFile: ".semaphore/run.yml",
				Parameters: map[string]string{
					"PARAM_1": "VALUE_1",
					"PARAM_2": "VALUE_2",
				},
			},
		}

		require.NoError(t, canvas.CreateStage("stage-task", user, false, template, []models.StageConnection{
			{
				SourceID:   source.ID,
				SourceType: models.SourceTypeEventSource,
			},
		}))

		stage, err := models.FindStageByName(org, canvas.ID, "stage-task")
		require.NoError(t, err)

		//
		// Create pending execution.
		//
		e, err := models.CreateEvent(source.ID, models.SourceTypeEventSource, []byte(`{}`))
		require.NoError(t, err)
		event, err := models.CreateStageEvent(stage.ID, e)
		require.NoError(t, err)
		execution, err := models.CreateStageExecution(stage.ID, event.ID)
		require.NoError(t, err)

		//
		// Trigger the worker, and verify that request to scheduler was sent,
		// and that execution was moved to 'started' state.
		//
		err = w.Tick()
		require.NoError(t, err)
		execution, err = stage.FindExecutionByID(execution.ID)
		require.NoError(t, err)
		assert.Equal(t, models.StageExecutionStarted, execution.State)
		assert.NotEmpty(t, execution.ReferenceID)
		assert.NotEmpty(t, execution.StartedAt)

		req := mockRegistry.SchedulerService.GetLastRunNowRequest()
		require.NotNil(t, req)
		assert.Equal(t, "demo-task", req.Id)
		assert.Equal(t, "main", req.Branch)
		assert.Equal(t, ".semaphore/run.yml", req.PipelineFile)
		assert.Equal(t, stage.CreatedBy.String(), req.Requester)

		require.Len(t, req.ParameterValues, 2)
		assert.True(t, slices.ContainsFunc(req.ParameterValues, func(v *schedulepb.ParameterValue) bool {
			return v.Name == "PARAM_1" && v.Value == "VALUE_1"
		}))
		assert.True(t, slices.ContainsFunc(req.ParameterValues, func(v *schedulepb.ParameterValue) bool {
			return v.Name == "PARAM_2" && v.Value == "VALUE_2"
		}))
	})
}
