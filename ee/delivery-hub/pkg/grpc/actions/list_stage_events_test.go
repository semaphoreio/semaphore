package actions

import (
	"context"
	"testing"

	uuid "github.com/google/uuid"
	protos "github.com/semaphoreio/semaphore/delivery-hub/pkg/protos/delivery"
	"github.com/semaphoreio/semaphore/delivery-hub/test/support"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

func Test__ListStageEvents(t *testing.T) {
	r := support.Setup(t)

	t.Run("no org ID -> error", func(t *testing.T) {
		_, err := ListStageEvents(context.Background(), &protos.ListStageEventsRequest{
			StageId:  uuid.New().String(),
			CanvasId: r.Canvas.ID.String(),
		})

		s, ok := status.FromError(err)
		assert.True(t, ok)
		assert.Equal(t, codes.InvalidArgument, s.Code())
		assert.Contains(t, s.Message(), "invalid UUID")
	})

	t.Run("no canvas ID -> error", func(t *testing.T) {
		_, err := ListStageEvents(context.Background(), &protos.ListStageEventsRequest{
			StageId:        uuid.New().String(),
			OrganizationId: r.Org.String(),
		})

		s, ok := status.FromError(err)
		assert.True(t, ok)
		assert.Equal(t, codes.InvalidArgument, s.Code())
		assert.Contains(t, s.Message(), "invalid UUID")
	})

	t.Run("stage does not exist -> error", func(t *testing.T) {
		_, err := ListStageEvents(context.Background(), &protos.ListStageEventsRequest{
			StageId:        uuid.New().String(),
			OrganizationId: r.Org.String(),
			CanvasId:       r.Canvas.ID.String(),
		})

		s, ok := status.FromError(err)
		assert.True(t, ok)
		assert.Equal(t, codes.InvalidArgument, s.Code())
		assert.Equal(t, "stage not found", s.Message())
	})

	t.Run("stage with no stage events -> empty list", func(t *testing.T) {
		res, err := ListStageEvents(context.Background(), &protos.ListStageEventsRequest{
			StageId:        r.Stage.ID.String(),
			CanvasId:       r.Canvas.ID.String(),
			OrganizationId: r.Org.String(),
		})

		require.NoError(t, err)
		require.NotNil(t, res)
		assert.Empty(t, res.Events)
	})

	t.Run("stage with stage events -> list", func(t *testing.T) {
		support.CreateStageEvent(t, r.Source, r.Stage)

		res, err := ListStageEvents(context.Background(), &protos.ListStageEventsRequest{
			OrganizationId: r.Org.String(),
			CanvasId:       r.Canvas.ID.String(),
			StageId:        r.Stage.ID.String(),
		})

		require.NoError(t, err)
		require.NotNil(t, res)
		require.Len(t, res.Events, 1)
		assert.NotEmpty(t, res.Events[0].Id)
		assert.NotEmpty(t, res.Events[0].CreatedAt)
		assert.Equal(t, r.Source.ID.String(), res.Events[0].SourceId)
		assert.Equal(t, protos.Connection_TYPE_EVENT_SOURCE, res.Events[0].SourceType)
		assert.Equal(t, protos.StageEvent_PENDING, res.Events[0].State)
		assert.Empty(t, res.Events[0].ApprovedAt)
		assert.Empty(t, res.Events[0].ApprovedBy)
	})
}
