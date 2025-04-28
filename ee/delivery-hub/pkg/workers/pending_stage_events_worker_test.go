package workers

import (
	"fmt"
	"testing"

	"github.com/google/uuid"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/config"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/models"
	"github.com/semaphoreio/semaphore/delivery-hub/test/support"
	testconsumer "github.com/semaphoreio/semaphore/delivery-hub/test/test_consumer"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func Test__PendingStageEventsWorker(t *testing.T) {
	r := support.SetupWithOptions(t, support.SetupOptions{Source: true})
	w := PendingStageEventsWorker{}
	amqpURL, _ := config.RabbitMQURL()

	t.Run("stage does not require approval -> creates execution", func(t *testing.T) {
		//
		// Create stage that does not require approval.
		//
		require.NoError(t, r.Canvas.CreateStage("stage-no-approval-1", r.User.String(), false, support.RunTemplate(), []models.StageConnection{
			{
				SourceID:   r.Source.ID,
				SourceType: models.SourceTypeEventSource,
			},
		}))

		stage, err := r.Canvas.FindStageByName("stage-no-approval-1")
		require.NoError(t, err)

		routingKey := fmt.Sprintf("%s.%s", "created", stage.ID.String())
		testconsumer := testconsumer.New(amqpURL, "DeliveryHub.ExecutionExchange", routingKey)
		testconsumer.Start()
		defer testconsumer.Stop()

		//
		// Create a pending stage event, and trigger the worker.
		//
		event := support.CreateStageEvent(t, r.Source, stage)
		err = w.Tick()
		require.NoError(t, err)

		//
		// Verify that a new execution record was created and event is processed.
		//
		event, err = models.FindStageEventByID(event.ID.String(), stage.ID.String())
		require.NoError(t, err)
		require.Equal(t, models.StageEventProcessed, event.State)
		execution, err := models.FindExecutionInState(stage.ID, []string{models.StageExecutionPending})
		require.NoError(t, err)
		assert.NotEmpty(t, execution.ID)
		assert.NotEmpty(t, execution.CreatedAt)
		assert.Equal(t, execution.StageID, stage.ID)
		assert.Equal(t, execution.StageEventID, event.ID)
		assert.Equal(t, execution.State, models.StageExecutionPending)
		assert.True(t, testconsumer.HasReceivedMessage())
	})

	t.Run("stage requires approval and none was given -> waiting-for-approval state", func(t *testing.T) {
		//
		// Create stage that requires approval.
		//
		require.NoError(t, r.Canvas.CreateStage("stage-with-approval-1", r.User.String(), true, support.RunTemplate(), []models.StageConnection{
			{
				SourceID:   r.Source.ID,
				SourceType: models.SourceTypeEventSource,
			},
		}))

		stage, err := r.Canvas.FindStageByName("stage-with-approval-1")
		require.NoError(t, err)

		//
		// Create a pending stage event, and trigger the worker.
		//
		event := support.CreateStageEvent(t, r.Source, stage)
		err = w.Tick()
		require.NoError(t, err)

		//
		// Verify that event was moved to the 'waiting-for-approval' state.
		//
		event, err = models.FindStageEventByID(event.ID.String(), stage.ID.String())
		require.NoError(t, err)
		require.Equal(t, models.StageEventWaitingForApproval, event.State)
	})

	t.Run("stage requires approval and approval was given -> creates execution", func(t *testing.T) {
		//
		// Create stage that requires approval.
		//
		require.NoError(t, r.Canvas.CreateStage("stage-with-approval-2", r.User.String(), true, support.RunTemplate(), []models.StageConnection{
			{
				SourceID:   r.Source.ID,
				SourceType: models.SourceTypeEventSource,
			},
		}))

		stage, err := r.Canvas.FindStageByName("stage-with-approval-2")
		require.NoError(t, err)

		routingKey := fmt.Sprintf("%s.%s", "created", stage.ID.String())
		testconsumer := testconsumer.New(amqpURL, "DeliveryHub.ExecutionExchange", routingKey)
		testconsumer.Start()
		defer testconsumer.Stop()

		//
		// Create a pending stage event, approve it, and trigger the worker.
		//
		event := support.CreateStageEvent(t, r.Source, stage)
		require.NoError(t, event.Approve(uuid.New().String()))
		err = w.Tick()
		require.NoError(t, err)

		//
		// Verify that a new execution record was created and event is processed
		//
		event, err = models.FindStageEventByID(event.ID.String(), stage.ID.String())
		require.NoError(t, err)
		require.Equal(t, models.StageEventProcessed, event.State)
		execution, err := models.FindExecutionInState(stage.ID, []string{models.StageExecutionPending})
		require.NoError(t, err)
		assert.NotEmpty(t, execution.ID)
		assert.NotEmpty(t, execution.CreatedAt)
		assert.Equal(t, execution.StageID, stage.ID)
		assert.Equal(t, execution.StageEventID, event.ID)
		assert.Equal(t, execution.State, models.StageExecutionPending)
		assert.True(t, testconsumer.HasReceivedMessage())
	})

	t.Run("another execution already in progress -> remains in pending state", func(t *testing.T) {
		//
		// Create stage that does not requires approval.
		//
		require.NoError(t, r.Canvas.CreateStage("stage-no-approval-3", r.User.String(), false, support.RunTemplate(), []models.StageConnection{
			{
				SourceID:   r.Source.ID,
				SourceType: models.SourceTypeEventSource,
			},
		}))

		stage, err := r.Canvas.FindStageByName("stage-no-approval-3")
		require.NoError(t, err)

		//
		// Create a pending stage event, trigger the worker,
		// and verify that it was processed.
		//
		event := support.CreateStageEvent(t, r.Source, stage)
		err = w.Tick()
		require.NoError(t, err)
		event, err = models.FindStageEventByID(event.ID.String(), stage.ID.String())
		require.NoError(t, err)
		require.Equal(t, models.StageEventProcessed, event.State)

		//
		// Add another pending event for this stage,
		// trigger the worker, and verify that it remained in the pending state.
		//
		event = support.CreateStageEvent(t, r.Source, stage)
		err = w.Tick()
		require.NoError(t, err)
		event, err = models.FindStageEventByID(event.ID.String(), stage.ID.String())
		require.NoError(t, err)
		require.Equal(t, models.StageEventPending, event.State)
	})
}
