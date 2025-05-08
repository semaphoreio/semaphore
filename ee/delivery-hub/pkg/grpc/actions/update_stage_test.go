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

const StageUpdatedRoutingKey = "stage-updated"

func Test__UpdateStage(t *testing.T) {
	r := support.SetupWithOptions(t, support.SetupOptions{Source: true})

	// Create a stage first that we'll update in tests
	runTemplate := support.ProtoRunTemplate()
	stage, err := CreateStage(context.Background(), &protos.CreateStageRequest{
		OrganizationId: r.Org.String(),
		CanvasId:       r.Canvas.ID.String(),
		Name:           "test-update-stage",
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
							Expression: "test == 1",
						},
					},
				},
			},
		},
	})
	require.NoError(t, err)
	require.NotNil(t, stage)
	stageID := stage.Stage.Id

	t.Run("invalid stage ID -> error", func(t *testing.T) {
		_, err := UpdateStage(context.Background(), &protos.UpdateStageRequest{
			Id:          "invalid-uuid",
			RequesterId: r.User.String(),
		})

		s, ok := status.FromError(err)
		assert.True(t, ok)
		assert.Equal(t, codes.InvalidArgument, s.Code())
		assert.Contains(t, s.Message(), "invalid UUID")
	})

	t.Run("missing requester ID -> error", func(t *testing.T) {
		_, err := UpdateStage(context.Background(), &protos.UpdateStageRequest{
			Id:          stageID,
			RequesterId: "",
		})

		s, ok := status.FromError(err)
		assert.True(t, ok)
		assert.Equal(t, codes.InvalidArgument, s.Code())
		assert.Contains(t, s.Message(), "invalid UUID")
	})

	t.Run("non-existent stage ID -> error", func(t *testing.T) {
		_, err := UpdateStage(context.Background(), &protos.UpdateStageRequest{
			Id:          uuid.New().String(),
			RequesterId: r.User.String(),
		})

		s, ok := status.FromError(err)
		assert.True(t, ok)
		assert.Equal(t, codes.NotFound, s.Code())
		assert.Contains(t, s.Message(), "stage not found")
	})

	t.Run("connection for source that does not exist -> error", func(t *testing.T) {
		_, err := UpdateStage(context.Background(), &protos.UpdateStageRequest{
			Id:          stageID,
			RequesterId: r.User.String(),
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
		assert.Contains(t, s.Message(), "invalid connections: event source source-does-not-exist not found")
	})

	t.Run("invalid filter -> error", func(t *testing.T) {
		_, err := UpdateStage(context.Background(), &protos.UpdateStageRequest{
			Id:          stageID,
			RequesterId: r.User.String(),
			Connections: []*protos.Connection{
				{
					Name: r.Source.Name,
					Type: protos.Connection_TYPE_EVENT_SOURCE,
					Filters: []*protos.Connection_Filter{
						{
							Type: protos.Connection_FILTER_TYPE_DATA,
							Data: &protos.Connection_DataFilter{
								Expression: "",
							},
						},
					},
				},
			},
		})

		s, ok := status.FromError(err)
		assert.True(t, ok)
		assert.Equal(t, codes.InvalidArgument, s.Code())
		assert.Contains(t, s.Message(), "invalid connections: invalid filter")
	})

	t.Run("stage is updated", func(t *testing.T) {
		amqpURL, _ := config.RabbitMQURL()
		testconsumer := testconsumer.New(amqpURL, StageUpdatedRoutingKey)
		testconsumer.Start()
		defer testconsumer.Stop()

		res, err := UpdateStage(context.Background(), &protos.UpdateStageRequest{
			Id:          stageID,
			RequesterId: r.User.String(),
			Connections: []*protos.Connection{
				{
					Name:           r.Source.Name,
					Type:           protos.Connection_TYPE_EVENT_SOURCE,
					FilterOperator: protos.Connection_FILTER_OPERATOR_OR,
					Filters: []*protos.Connection_Filter{
						{
							Type: protos.Connection_FILTER_TYPE_DATA,
							Data: &protos.Connection_DataFilter{
								Expression: "test == 42",
							},
						},
						{
							Type: protos.Connection_FILTER_TYPE_DATA,
							Data: &protos.Connection_DataFilter{
								Expression: "status == 'active'",
							},
						},
					},
				},
			},
		})

		require.NoError(t, err)
		require.NotNil(t, res)
		assert.Equal(t, stageID, res.Stage.Id)
		assert.Equal(t, r.Org.String(), res.Stage.OrganizationId)
		assert.Equal(t, r.Canvas.ID.String(), res.Stage.CanvasId)
		assert.Equal(t, "test-update-stage", res.Stage.Name)
		assert.Equal(t, runTemplate, res.Stage.RunTemplate)

		require.Len(t, res.Stage.Connections, 1)
		assert.Equal(t, r.Source.Name, res.Stage.Connections[0].Name)
		assert.Equal(t, protos.Connection_TYPE_EVENT_SOURCE, res.Stage.Connections[0].Type)
		assert.Equal(t, protos.Connection_FILTER_OPERATOR_OR, res.Stage.Connections[0].FilterOperator)
		require.Len(t, res.Stage.Connections[0].Filters, 2)
		assert.Equal(t, "test == 42", res.Stage.Connections[0].Filters[0].Data.Expression)
		assert.Equal(t, "status == 'active'", res.Stage.Connections[0].Filters[1].Data.Expression)

		assert.True(t, testconsumer.HasReceivedMessage())
	})

	t.Run("update to empty connections", func(t *testing.T) {
		res, err := UpdateStage(context.Background(), &protos.UpdateStageRequest{
			Id:          stageID,
			RequesterId: r.User.String(),
			Connections: []*protos.Connection{},
		})

		require.NoError(t, err)
		require.NotNil(t, res)
		assert.Equal(t, stageID, res.Stage.Id)

		assert.Empty(t, res.Stage.Connections)
	})

	t.Run("update keeps existing conditions", func(t *testing.T) {
		stageWithConditions, err := CreateStage(context.Background(), &protos.CreateStageRequest{
			OrganizationId: r.Org.String(),
			CanvasId:       r.Canvas.ID.String(),
			Name:           "test-conditions-preserve",
			RunTemplate:    runTemplate,
			RequesterId:    r.User.String(),
			Conditions: []*protos.Condition{
				{
					Type:     protos.Condition_CONDITION_TYPE_APPROVAL,
					Approval: &protos.ConditionApproval{Count: 2},
				},
			},
		})
		require.NoError(t, err)
		require.NotNil(t, stageWithConditions)
		conditionStageID := stageWithConditions.Stage.Id

		// Update connections but not conditions
		res, err := UpdateStage(context.Background(), &protos.UpdateStageRequest{
			Id:          conditionStageID,
			RequesterId: r.User.String(),
			Connections: []*protos.Connection{
				{
					Name: r.Source.Name,
					Type: protos.Connection_TYPE_EVENT_SOURCE,
					Filters: []*protos.Connection_Filter{
						{
							Type: protos.Connection_FILTER_TYPE_DATA,
							Data: &protos.Connection_DataFilter{
								Expression: "test == 100",
							},
						},
					},
				},
			},
		})

		require.NoError(t, err)
		require.NotNil(t, res)

		// Verify conditions were preserved
		require.Len(t, res.Stage.Conditions, 1)
		assert.Equal(t, protos.Condition_CONDITION_TYPE_APPROVAL, res.Stage.Conditions[0].Type)
		assert.Equal(t, uint32(2), res.Stage.Conditions[0].Approval.Count)
	})
}
