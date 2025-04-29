package actions

import (
	"context"
	"testing"

	uuid "github.com/google/uuid"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/config"
	protos "github.com/semaphoreio/semaphore/delivery-hub/pkg/protos/delivery"
	"github.com/semaphoreio/semaphore/delivery-hub/test/support"
	testconsumer "github.com/semaphoreio/semaphore/delivery-hub/test/test_consumer"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

const StageCreatedRoutingKey = "stage-created"

func Test__CreateStage(t *testing.T) {
	r := support.SetupWithOptions(t, support.SetupOptions{Source: true})

	t.Run("canvas does not exist -> error", func(t *testing.T) {
		_, err := CreateStage(context.Background(), &protos.CreateStageRequest{
			OrganizationId: r.Org.String(),
			CanvasId:       uuid.New().String(),
			Name:           "test",
			RequesterId:    r.User.String(),
			RunTemplate:    support.ProtoRunTemplate(),
		})

		s, ok := status.FromError(err)
		assert.True(t, ok)
		assert.Equal(t, codes.InvalidArgument, s.Code())
		assert.Equal(t, "canvas not found", s.Message())
	})

	t.Run("missing requester ID -> error", func(t *testing.T) {
		_, err := CreateStage(context.Background(), &protos.CreateStageRequest{
			OrganizationId: r.Org.String(),
			CanvasId:       r.Canvas.ID.String(),
			Name:           "test",
			RunTemplate:    support.ProtoRunTemplate(),
		})

		s, ok := status.FromError(err)
		assert.True(t, ok)
		assert.Equal(t, codes.InvalidArgument, s.Code())
		assert.Contains(t, s.Message(), "invalid UUID")
	})

	t.Run("connection for source that does not exist -> error", func(t *testing.T) {
		_, err := CreateStage(context.Background(), &protos.CreateStageRequest{
			OrganizationId: r.Org.String(),
			CanvasId:       r.Canvas.ID.String(),
			Name:           "test",
			RunTemplate:    support.ProtoRunTemplate(),
			RequesterId:    r.User.String(),
			Connections: []*protos.Connection{
				{
					Name: "source-does-not-exist",
					Type: protos.Connection_TYPE_EVENT_SOURCE,
				},
			},
		})

		s, ok := status.FromError(err)
		assert.True(t, ok)
		assert.Equal(t, codes.InvalidArgument, s.Code())
		assert.Equal(t, "invalid connection: event source source-does-not-exist not found", s.Message())
	})

	t.Run("stage with connection with filters", func(t *testing.T) {
		amqpURL, _ := config.RabbitMQURL()
		testconsumer := testconsumer.New(amqpURL, StageCreatedRoutingKey)
		testconsumer.Start()
		defer testconsumer.Stop()

		runTemplate := support.ProtoRunTemplate()
		res, err := CreateStage(context.Background(), &protos.CreateStageRequest{
			OrganizationId: r.Org.String(),
			CanvasId:       r.Canvas.ID.String(),
			Name:           "test",
			RunTemplate:    runTemplate,
			RequesterId:    r.User.String(),
			Connections: []*protos.Connection{
				{
					Name: r.Source.Name,
					Type: protos.Connection_TYPE_EVENT_SOURCE,
					Filters: []*protos.Connection_Filter{
						{
							Type: protos.Connection_FILTER_TYPE_DATA,
							Data: &protos.Connection_DataFilter{
								Expression: "test == 12",
							},
						},
					},
				},
			},
		})

		require.NoError(t, err)
		require.NotNil(t, res)
		assert.NotNil(t, res.Stage.Id)
		assert.NotNil(t, res.Stage.CreatedAt)
		assert.Equal(t, r.Org.String(), res.Stage.OrganizationId)
		assert.Equal(t, r.Canvas.ID.String(), res.Stage.CanvasId)
		assert.Equal(t, "test", res.Stage.Name)
		assert.Equal(t, runTemplate, res.Stage.RunTemplate)
		assert.Len(t, res.Stage.Connections, 1)
		assert.Len(t, res.Stage.Connections[0].Filters, 1)
		assert.Equal(t, protos.Connection_FILTER_OPERATOR_AND, res.Stage.Connections[0].FilterOperator)
		assert.True(t, testconsumer.HasReceivedMessage())
	})

	t.Run("stage name already used -> error", func(t *testing.T) {
		_, err := CreateStage(context.Background(), &protos.CreateStageRequest{
			OrganizationId: r.Org.String(),
			CanvasId:       r.Canvas.ID.String(),
			Name:           "test",
			RequesterId:    r.User.String(),
			RunTemplate:    support.ProtoRunTemplate(),
		})

		s, ok := status.FromError(err)
		assert.True(t, ok)
		assert.Equal(t, codes.InvalidArgument, s.Code())
		assert.Equal(t, "name already used", s.Message())
	})
}
