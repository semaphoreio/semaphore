package grpc

import (
	"context"
	"testing"

	uuid "github.com/google/uuid"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/database"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/encryptor"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/models"
	protos "github.com/semaphoreio/semaphore/delivery-hub/pkg/protos/delivery"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

func Test__CreateCanvas(t *testing.T) {
	require.NoError(t, database.TruncateTables())

	service := NewDeliveryService(&encryptor.NoOpEncryptor{})
	orgID := uuid.New()

	t.Run("name still not used -> canvas is created", func(t *testing.T) {
		response, err := service.CreateCanvas(context.Background(), &protos.CreateCanvasRequest{
			OrganizationId: orgID.String(),
			Name:           "test",
		})

		require.NoError(t, err)
		require.NotNil(t, response)
		require.NotNil(t, response.Canvas)
		assert.NotEmpty(t, response.Canvas.Id)
		assert.NotEmpty(t, response.Canvas.CreatedAt)
		assert.Equal(t, "test", response.Canvas.Name)
		assert.Equal(t, orgID.String(), response.Canvas.OrganizationId)
	})

	t.Run("name already used -> error", func(t *testing.T) {
		_, err := service.CreateCanvas(context.Background(), &protos.CreateCanvasRequest{
			OrganizationId: orgID.String(),
			Name:           "test",
		})

		s, ok := status.FromError(err)
		assert.True(t, ok)
		assert.Equal(t, codes.InvalidArgument, s.Code())
		assert.Equal(t, "name already used", s.Message())
	})
}

func Test__DescribeCanvas(t *testing.T) {
	require.NoError(t, database.TruncateTables())

	service := NewDeliveryService(&encryptor.NoOpEncryptor{})
	orgID := uuid.New()

	t.Run("canvas does not exist -> error", func(t *testing.T) {
		_, err := service.DescribeCanvas(context.Background(), &protos.DescribeCanvasRequest{
			OrganizationId: orgID.String(),
			Id:             uuid.New().String(),
		})

		s, ok := status.FromError(err)
		assert.True(t, ok)
		assert.Equal(t, codes.NotFound, s.Code())
		assert.Equal(t, "canvas not found", s.Message())
	})

	t.Run("empty canvas", func(t *testing.T) {
		canvas, err := models.CreateCanvas(orgID, "test")
		require.NoError(t, err)

		response, err := service.DescribeCanvas(context.Background(), &protos.DescribeCanvasRequest{
			OrganizationId: orgID.String(),
			Id:             canvas.ID.String(),
		})

		require.NoError(t, err)
		require.NotNil(t, response)
		require.NotNil(t, response.Canvas)
		assert.Equal(t, canvas.ID.String(), response.Canvas.Id)
		assert.Equal(t, *canvas.CreatedAt, response.Canvas.CreatedAt.AsTime())
		assert.Equal(t, "test", response.Canvas.Name)
		assert.Empty(t, response.Canvas.Stages)
		assert.Empty(t, response.Canvas.EventSources)
	})

	t.Run("canvas with sources, stages and connections", func(t *testing.T) {
		canvas, err := models.CreateCanvas(orgID, "test-2")
		require.NoError(t, err)

		eventSource, err := models.CreateEventSource("gh", canvas.OrganizationID, canvas.ID, []byte("my-key"))
		require.NoError(t, err)

		//
		// Connection only to the event source
		//
		err = models.CreateStage(
			canvas.OrganizationID,
			canvas.ID,
			"stage-1",
			[]models.StageConnection{
				{
					SourceID: eventSource.ID,
					Type:     protos.Connection_TYPE_EVENT_SOURCE.String(),
				},
			},
		)

		require.NoError(t, err)
		stage1, err := models.FindStageByName(orgID, canvas.ID, "stage-1")
		require.NoError(t, err)

		//
		// Connection to the event source and also with the previous stage
		//
		err = models.CreateStage(
			canvas.OrganizationID,
			canvas.ID,
			"stage-2",
			[]models.StageConnection{
				{
					SourceID: eventSource.ID,
					Type:     protos.Connection_TYPE_EVENT_SOURCE.String(),
				},
				{
					SourceID: stage1.ID,
					Type:     protos.Connection_TYPE_STAGE.String(),
				},
			},
		)

		require.NoError(t, err)

		response, err := service.DescribeCanvas(context.Background(), &protos.DescribeCanvasRequest{
			OrganizationId: orgID.String(),
			Id:             canvas.ID.String(),
		})

		require.NoError(t, err)
		require.NotNil(t, response)
		require.NotNil(t, response.Canvas)
		assert.Equal(t, canvas.ID.String(), response.Canvas.Id)
		assert.Equal(t, *canvas.CreatedAt, response.Canvas.CreatedAt.AsTime())
		assert.Equal(t, "test-2", response.Canvas.Name)

		require.Len(t, response.Canvas.EventSources, 1)
		assert.Equal(t, eventSource.ID.String(), response.Canvas.EventSources[0].Id)
		assert.Equal(t, "gh", response.Canvas.EventSources[0].Name)

		require.Len(t, response.Canvas.Stages, 2)

		//
		// First stage has just one connection to an event source
		//
		assert.Equal(t, "stage-1", response.Canvas.Stages[0].Name)
		require.Len(t, response.Canvas.Stages[0].Connections, 1)
		assert.Equal(t, "gh", response.Canvas.Stages[0].Connections[0].Name)
		assert.Equal(t, protos.Connection_TYPE_EVENT_SOURCE, response.Canvas.Stages[0].Connections[0].Type)

		//
		// Second stage just two connections: with a event source and another stage
		//
		assert.Equal(t, "stage-2", response.Canvas.Stages[1].Name)
		require.Len(t, response.Canvas.Stages[1].Connections, 2)
		assert.Equal(t, "gh", response.Canvas.Stages[1].Connections[0].Name)
		assert.Equal(t, protos.Connection_TYPE_EVENT_SOURCE, response.Canvas.Stages[1].Connections[0].Type)
		assert.Equal(t, "stage-1", response.Canvas.Stages[1].Connections[1].Name)
		assert.Equal(t, protos.Connection_TYPE_STAGE, response.Canvas.Stages[1].Connections[1].Type)
	})
}

func Test__CreateEventSource(t *testing.T) {
	require.NoError(t, database.TruncateTables())

	service := NewDeliveryService(&encryptor.NoOpEncryptor{})
	orgID := uuid.New()

	canvas, err := models.CreateCanvas(orgID, "test")
	require.NoError(t, err)

	t.Run("canvas does not exist -> error", func(t *testing.T) {
		req := &protos.CreateEventSourceRequest{
			OrganizationId: orgID.String(),
			CanvasId:       uuid.New().String(),
			Name:           "test",
		}

		_, err := service.CreateEventSource(context.Background(), req)
		s, ok := status.FromError(err)
		assert.True(t, ok)
		assert.Equal(t, codes.InvalidArgument, s.Code())
		assert.Equal(t, "canvas not found", s.Message())
	})

	t.Run("name still not used -> event source is created", func(t *testing.T) {
		response, err := service.CreateEventSource(context.Background(), &protos.CreateEventSourceRequest{
			OrganizationId: orgID.String(),
			CanvasId:       canvas.ID.String(),
			Name:           "test",
		})

		require.NoError(t, err)
		require.NotNil(t, response)
		require.NotNil(t, response.EventSource)
		assert.NotEmpty(t, response.EventSource.Id)
		assert.NotEmpty(t, response.EventSource.CreatedAt)
		assert.NotEmpty(t, response.Key)
		assert.Equal(t, "test", response.EventSource.Name)
		assert.Equal(t, orgID.String(), response.EventSource.OrganizationId)
		assert.Equal(t, canvas.ID.String(), response.EventSource.CanvasId)
	})

	t.Run("name already used -> error", func(t *testing.T) {
		_, err := service.CreateEventSource(context.Background(), &protos.CreateEventSourceRequest{
			OrganizationId: orgID.String(),
			CanvasId:       canvas.ID.String(),
			Name:           "test",
		})

		s, ok := status.FromError(err)
		assert.True(t, ok)
		assert.Equal(t, codes.InvalidArgument, s.Code())
		assert.Equal(t, "name already used", s.Message())
	})
}

func Test__CreateStage(t *testing.T) {
	require.NoError(t, database.TruncateTables())

	service := NewDeliveryService(&encryptor.NoOpEncryptor{})
	orgID := uuid.New()

	canvas, err := models.CreateCanvas(orgID, "test")
	require.NoError(t, err)

	t.Run("canvas does not exist -> error", func(t *testing.T) {
		_, err := service.CreateStage(context.Background(), &protos.CreateStageRequest{
			OrganizationId: orgID.String(),
			CanvasId:       uuid.New().String(),
			Name:           "test",
		})

		s, ok := status.FromError(err)
		assert.True(t, ok)
		assert.Equal(t, codes.InvalidArgument, s.Code())
		assert.Equal(t, "canvas not found", s.Message())
	})

	t.Run("stage is created", func(t *testing.T) {
		res, err := service.CreateStage(context.Background(), &protos.CreateStageRequest{
			OrganizationId: orgID.String(),
			CanvasId:       canvas.ID.String(),
			Name:           "test",
		})

		require.NoError(t, err)
		require.NotNil(t, res)
		assert.NotNil(t, res.Stage.Id)
		assert.NotNil(t, res.Stage.CreatedAt)
		assert.Equal(t, orgID.String(), res.Stage.OrganizationId)
		assert.Equal(t, canvas.ID.String(), res.Stage.CanvasId)
		assert.Equal(t, "test", res.Stage.Name)
		assert.Empty(t, res.Stage.Connections)
	})

	t.Run("stage name already used -> error", func(t *testing.T) {
		_, err := service.CreateStage(context.Background(), &protos.CreateStageRequest{
			OrganizationId: orgID.String(),
			CanvasId:       canvas.ID.String(),
			Name:           "test",
		})

		s, ok := status.FromError(err)
		assert.True(t, ok)
		assert.Equal(t, codes.InvalidArgument, s.Code())
		assert.Equal(t, "name already used", s.Message())
	})
}
