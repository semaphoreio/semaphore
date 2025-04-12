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
