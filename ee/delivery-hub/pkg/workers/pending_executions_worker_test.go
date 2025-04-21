package workers

import (
	"slices"
	"testing"

	"github.com/semaphoreio/semaphore/delivery-hub/pkg/models"
	schedulepb "github.com/semaphoreio/semaphore/delivery-hub/pkg/protos/periodic_scheduler"
	"github.com/semaphoreio/semaphore/delivery-hub/test/support"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func Test__PendingExecutionsWorker(t *testing.T) {
	r := support.SetupWithOptions(t, support.SetupOptions{Source: true, Grpc: true})
	w := PendingExecutionsWorker{
		RepoProxyURL: "0.0.0.0:50052",
		SchedulerURL: "0.0.0.0:50052",
	}

	t.Run("semaphore workflow is created", func(t *testing.T) {
		//
		// Create stage that creates Semaphore workflows.
		//
		require.NoError(t, r.Canvas.CreateStage("stage-wf", r.User.String(), false, support.RunTemplate(), []models.StageConnection{
			{
				SourceID:   r.Source.ID,
				SourceType: models.SourceTypeEventSource,
			},
		}))

		stage, err := r.Canvas.FindStageByName("stage-wf")
		require.NoError(t, err)

		//
		// Create pending execution.
		//
		execution := support.CreateExecution(t, r.Source, stage)

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
		repoProxyReq := r.Grpc.RepoProxyService.GetLastCreateRequest()
		require.NotNil(t, repoProxyReq)
		assert.Equal(t, "demo-project", repoProxyReq.ProjectId)
		assert.Equal(t, ".semaphore/semaphore.yml", repoProxyReq.DefinitionFile)
		assert.Equal(t, stage.CreatedBy.String(), repoProxyReq.RequesterId)
		assert.Equal(t, "refs/heads/main", repoProxyReq.Git.Reference)
	})

	t.Run("semaphore task is triggered", func(t *testing.T) {
		//
		// Create stage that trigger Semaphore task.
		//
		require.NoError(t, r.Canvas.CreateStage("stage-task", r.User.String(), false, support.TaskRunTemplate(), []models.StageConnection{
			{
				SourceID:   r.Source.ID,
				SourceType: models.SourceTypeEventSource,
			},
		}))

		stage, err := r.Canvas.FindStageByName("stage-task")
		require.NoError(t, err)

		//
		// Create pending execution.
		//
		e, err := models.CreateEvent(r.Source.ID, r.Source.Name, models.SourceTypeEventSource, []byte(`{}`))
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

		req := r.Grpc.SchedulerService.GetLastRunNowRequest()
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
