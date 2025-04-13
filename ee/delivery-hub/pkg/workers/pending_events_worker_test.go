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

func Test__PendingEventsWorker(t *testing.T) {
	require.NoError(t, database.TruncateTables())

	org := uuid.New()

	canvas, err := models.CreateCanvas(org, "test")
	require.NoError(t, err)

	source, err := canvas.CreateEventSource("gh", []byte("my-key"))
	require.NoError(t, err)

	w := PendingEventsWorker{}

	t.Run("source is not connected to any stage -> event is discarded", func(t *testing.T) {
		event, err := models.CreateEvent(source.ID, []byte(`{}`))
		require.NoError(t, err)

		err = w.Tick()
		require.NoError(t, err)

		event, err = models.FindEventByID(event.ID)
		require.NoError(t, err)
		assert.Equal(t, models.EventStateDiscarded, event.State)
	})

	t.Run("source is connected to many stages -> event is added to each stage queue", func(t *testing.T) {
		//
		// Create two stages, connecting event source to them.
		//
		err := canvas.CreateStage("stage-1", false, []models.StageConnection{
			{
				SourceID: source.ID,
				Type:     protos.Connection_TYPE_EVENT_SOURCE.String(),
			},
		})

		require.NoError(t, err)

		err = canvas.CreateStage("stage-2", false, []models.StageConnection{
			{
				SourceID: source.ID,
				Type:     protos.Connection_TYPE_EVENT_SOURCE.String(),
			},
		})

		require.NoError(t, err)

		//
		// Create an event for the source, and trigger the worker.
		//
		event, err := models.CreateEvent(source.ID, []byte(`{}`))
		require.NoError(t, err)
		err = w.Tick()
		require.NoError(t, err)

		//
		// Event is moved to processed state.
		//
		event, err = models.FindEventByID(event.ID)
		require.NoError(t, err)
		assert.Equal(t, models.EventStateProcessed, event.State)

		//
		// Two pending stage events are created: one for each stage.
		//

		stage1, _ := models.FindStageByName(org, canvas.ID, "stage-1")
		stage2, _ := models.FindStageByName(org, canvas.ID, "stage-2")
		stage1Events, err := stage1.ListEvents()
		require.NoError(t, err)
		require.Len(t, stage1Events, 1)
		assert.Equal(t, source.ID, stage1Events[0].SourceID)
		assert.Equal(t, models.StageEventPending, stage1Events[0].State)

		stage2Events, err := stage2.ListEvents()
		require.NoError(t, err)
		require.Len(t, stage2Events, 1)
		assert.Equal(t, source.ID, stage2Events[0].SourceID)
		assert.Equal(t, models.StageEventPending, stage2Events[0].State)
	})
}
