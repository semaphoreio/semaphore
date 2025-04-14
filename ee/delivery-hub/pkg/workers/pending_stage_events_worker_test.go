package workers

import (
	"testing"

	"github.com/google/uuid"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/database"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/models"
	protos "github.com/semaphoreio/semaphore/delivery-hub/pkg/protos/delivery"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func Test__PendingStageEventsWorker(t *testing.T) {
	require.NoError(t, database.TruncateTables())

	org := uuid.New()
	user := uuid.New()

	canvas, err := models.CreateCanvas(org, "test")
	require.NoError(t, err)

	source, err := canvas.CreateEventSource("gh", []byte("my-key"))
	require.NoError(t, err)

	template := models.RunTemplate{
		Type: protos.RunTemplate_TYPE_SEMAPHORE_WORKFLOW.String(),
		SemaphoreWorkflow: &models.SemaphoreWorkflowTemplate{
			Project:      "demo-project",
			Branch:       "main",
			PipelineFile: ".semaphore/semaphore.yml",
		},
	}

	w := PendingStageEventsWorker{}

	t.Run("stage does not require approval -> creates execution", func(t *testing.T) {
		//
		// Create stage that does not require approval.
		//
		require.NoError(t, canvas.CreateStage("stage-no-approval-1", user, false, template, []models.StageConnection{
			{
				SourceID: source.ID,
				Type:     protos.Connection_TYPE_EVENT_SOURCE.String(),
			},
		}))

		stage, err := models.FindStageByName(org, canvas.ID, "stage-no-approval-1")
		require.NoError(t, err)

		//
		// Create a pending stage event, and trigger the worker.
		//
		event, err := models.CreateStageEvent(stage.ID, source.ID)
		require.NoError(t, err)
		require.NotNil(t, event)
		require.Equal(t, models.StageEventPending, event.State)
		err = w.Tick()
		require.NoError(t, err)

		//
		// Verify that event was moved to the 'waiting-for-execution' state,
		// and new execution record was created.
		//
		event, err = models.FindStageEventByID(event.ID, stage.ID)
		require.NoError(t, err)
		require.Equal(t, models.StageEventWaitingForExecution, event.State)
		execution, err := models.FindExecutionInState(stage.ID, []string{models.StageExecutionPending})
		require.NoError(t, err)
		assert.NotEmpty(t, execution.ID)
		assert.NotEmpty(t, execution.CreatedAt)
		assert.Equal(t, execution.StageID, stage.ID)
		assert.Equal(t, execution.StageEventID, event.ID)
		assert.Equal(t, execution.State, models.StageExecutionPending)
	})

	t.Run("stage requires approval and none was given -> waiting-for-approval state", func(t *testing.T) {
		//
		// Create stage that requires approval.
		//
		require.NoError(t, canvas.CreateStage("stage-with-approval-1", user, true, template, []models.StageConnection{
			{
				SourceID: source.ID,
				Type:     protos.Connection_TYPE_EVENT_SOURCE.String(),
			},
		}))

		stage, err := models.FindStageByName(org, canvas.ID, "stage-with-approval-1")
		require.NoError(t, err)

		//
		// Create a pending stage event, and trigger the worker.
		//
		event, err := models.CreateStageEvent(stage.ID, source.ID)
		require.NoError(t, err)
		require.NotNil(t, event)
		require.Equal(t, models.StageEventPending, event.State)
		err = w.Tick()
		require.NoError(t, err)

		//
		// Verify that event was moved to the 'waiting-for-approval' state.
		//
		event, err = models.FindStageEventByID(event.ID, stage.ID)
		require.NoError(t, err)
		require.Equal(t, models.StageEventWaitingForApproval, event.State)
	})

	t.Run("stage requires approval and approval was given -> creates execution", func(t *testing.T) {
		//
		// Create stage that requires approval.
		//
		require.NoError(t, canvas.CreateStage("stage-with-approval-2", user, true, template, []models.StageConnection{
			{
				SourceID: source.ID,
				Type:     protos.Connection_TYPE_EVENT_SOURCE.String(),
			},
		}))

		stage, err := models.FindStageByName(org, canvas.ID, "stage-with-approval-2")
		require.NoError(t, err)

		//
		// Create a pending stage event, approve it, and trigger the worker.
		//
		event, err := models.CreateStageEvent(stage.ID, source.ID)
		require.NoError(t, err)
		require.NotNil(t, event)
		require.NoError(t, event.Approve(uuid.New()))
		require.Equal(t, models.StageEventPending, event.State)
		err = w.Tick()
		require.NoError(t, err)

		//
		// Verify that event was moved to the 'waiting-for-execution' state,
		// and new execution record was created.
		//
		event, err = models.FindStageEventByID(event.ID, stage.ID)
		require.NoError(t, err)
		require.Equal(t, models.StageEventWaitingForExecution, event.State)
		execution, err := models.FindExecutionInState(stage.ID, []string{models.StageExecutionPending})
		require.NoError(t, err)
		assert.NotEmpty(t, execution.ID)
		assert.NotEmpty(t, execution.CreatedAt)
		assert.Equal(t, execution.StageID, stage.ID)
		assert.Equal(t, execution.StageEventID, event.ID)
		assert.Equal(t, execution.State, models.StageExecutionPending)
	})

	t.Run("another execution already in progress -> remains in pending state", func(t *testing.T) {
		//
		// Create stage that does not requires approval.
		//
		require.NoError(t, canvas.CreateStage("stage-no-approval-3", user, false, template, []models.StageConnection{
			{
				SourceID: source.ID,
				Type:     protos.Connection_TYPE_EVENT_SOURCE.String(),
			},
		}))

		stage, err := models.FindStageByName(org, canvas.ID, "stage-no-approval-3")
		require.NoError(t, err)

		//
		// Create a pending stage event, trigger the worker,
		// and verify that it moved to the waiting-for-execution state.
		//
		event, err := models.CreateStageEvent(stage.ID, source.ID)
		require.NoError(t, err)
		require.NotNil(t, event)
		require.Equal(t, models.StageEventPending, event.State)
		err = w.Tick()
		require.NoError(t, err)
		event, err = models.FindStageEventByID(event.ID, stage.ID)
		require.NoError(t, err)
		require.Equal(t, models.StageEventWaitingForExecution, event.State)

		//
		// Add another pending event for this stage,
		// trigger the worker, and verify that it remained in the pending state.
		//
		event, err = models.CreateStageEvent(stage.ID, source.ID)
		require.NoError(t, err)
		require.Equal(t, models.StageEventPending, event.State)
		err = w.Tick()
		require.NoError(t, err)
		event, err = models.FindStageEventByID(event.ID, stage.ID)
		require.NoError(t, err)
		require.Equal(t, models.StageEventPending, event.State)
	})
}
