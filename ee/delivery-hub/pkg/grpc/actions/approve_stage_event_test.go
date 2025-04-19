package actions

import (
	"context"
	"testing"

	uuid "github.com/google/uuid"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/models"
	protos "github.com/semaphoreio/semaphore/delivery-hub/pkg/protos/delivery"
	"github.com/semaphoreio/semaphore/delivery-hub/test/support"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

func Test__ApproveStageEvent(t *testing.T) {
	r := support.Setup(t)
	e, err := models.CreateEvent(r.Source.ID, models.SourceTypeEventSource, []byte(`{}`))
	require.NoError(t, err)
	event, err := models.CreateStageEvent(r.Stage.ID, e)
	require.NoError(t, err)

	t.Run("no org ID -> error", func(t *testing.T) {
		_, err := ApproveStageEvent(context.Background(), &protos.ApproveStageEventRequest{
			StageId:     uuid.New().String(),
			CanvasId:    r.Canvas.ID.String(),
			EventId:     event.ID.String(),
			RequesterId: uuid.New().String(),
		})

		s, ok := status.FromError(err)
		assert.True(t, ok)
		assert.Equal(t, codes.InvalidArgument, s.Code())
		assert.Contains(t, s.Message(), "invalid UUID")
	})

	t.Run("no canvas ID -> error", func(t *testing.T) {
		_, err := ApproveStageEvent(context.Background(), &protos.ApproveStageEventRequest{
			StageId:        uuid.New().String(),
			OrganizationId: r.Canvas.OrganizationID.String(),
			EventId:        event.ID.String(),
			RequesterId:    uuid.New().String(),
		})

		s, ok := status.FromError(err)
		assert.True(t, ok)
		assert.Equal(t, codes.InvalidArgument, s.Code())
		assert.Contains(t, s.Message(), "invalid UUID")
	})

	t.Run("stage does not exist -> error", func(t *testing.T) {
		_, err := ApproveStageEvent(context.Background(), &protos.ApproveStageEventRequest{
			OrganizationId: r.Canvas.OrganizationID.String(),
			CanvasId:       r.Canvas.ID.String(),
			StageId:        uuid.New().String(),
			EventId:        event.ID.String(),
			RequesterId:    uuid.New().String(),
		})

		s, ok := status.FromError(err)
		assert.True(t, ok)
		assert.Equal(t, codes.InvalidArgument, s.Code())
		assert.Equal(t, "stage not found", s.Message())
	})

	t.Run("stage event does not exist -> error", func(t *testing.T) {
		_, err := ApproveStageEvent(context.Background(), &protos.ApproveStageEventRequest{
			OrganizationId: r.Canvas.OrganizationID.String(),
			CanvasId:       r.Canvas.ID.String(),
			StageId:        r.Stage.ID.String(),
			EventId:        uuid.New().String(),
			RequesterId:    uuid.New().String(),
		})

		s, ok := status.FromError(err)
		assert.True(t, ok)
		assert.Equal(t, codes.InvalidArgument, s.Code())
		assert.Equal(t, "event not found", s.Message())
	})

	t.Run("stage with stage events -> approves and returns event", func(t *testing.T) {
		res, err := ApproveStageEvent(context.Background(), &protos.ApproveStageEventRequest{
			OrganizationId: r.Canvas.OrganizationID.String(),
			CanvasId:       r.Canvas.ID.String(),
			StageId:        r.Stage.ID.String(),
			EventId:        event.ID.String(),
			RequesterId:    uuid.New().String(),
		})

		require.NoError(t, err)
		require.NotNil(t, res)
		require.NotNil(t, res.Event)
		assert.Equal(t, event.ID.String(), res.Event.Id)
		assert.Equal(t, r.Source.ID.String(), res.Event.SourceId)
		assert.Equal(t, protos.Connection_TYPE_EVENT_SOURCE, res.Event.SourceType)
		assert.Equal(t, protos.StageEvent_PENDING, res.Event.State)
		assert.NotNil(t, res.Event.CreatedAt)
		assert.NotNil(t, res.Event.ApprovedAt)
	})
}
