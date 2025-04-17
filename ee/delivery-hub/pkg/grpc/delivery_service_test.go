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
	user := uuid.New()

	t.Run("name still not used -> canvas is created", func(t *testing.T) {
		response, err := service.CreateCanvas(context.Background(), &protos.CreateCanvasRequest{
			OrganizationId: orgID.String(),
			RequesterId:    user.String(),
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
			RequesterId:    user.String(),
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
	userID := uuid.New()

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
		canvas, err := models.CreateCanvas(orgID, userID, "test")
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
		assert.Equal(t, canvas.CreatedBy.String(), response.Canvas.CreatedBy)
	})
}

func Test__CreateEventSource(t *testing.T) {
	require.NoError(t, database.TruncateTables())

	service := NewDeliveryService(&encryptor.NoOpEncryptor{})
	orgID := uuid.New()
	userID := uuid.New()

	canvas, err := models.CreateCanvas(orgID, userID, "test")
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
	requesterID := uuid.New()

	canvas, err := models.CreateCanvas(orgID, requesterID, "test")
	require.NoError(t, err)

	source, err := canvas.CreateEventSource("gh", []byte("my-key"))
	require.NoError(t, err)

	template := protos.RunTemplate{
		Type: protos.RunTemplate_TYPE_SEMAPHORE_WORKFLOW,
		SemaphoreWorkflow: &protos.WorkflowTemplate{
			ProjectId:    "test",
			Branch:       "main",
			PipelineFile: ".semaphore/semaphore.yml",
		},
	}

	t.Run("canvas does not exist -> error", func(t *testing.T) {
		_, err := service.CreateStage(context.Background(), &protos.CreateStageRequest{
			OrganizationId: orgID.String(),
			CanvasId:       uuid.New().String(),
			Name:           "test",
			RequesterId:    requesterID.String(),
			RunTemplate:    &template,
		})

		s, ok := status.FromError(err)
		assert.True(t, ok)
		assert.Equal(t, codes.InvalidArgument, s.Code())
		assert.Equal(t, "canvas not found", s.Message())
	})

	t.Run("missing requester ID -> error", func(t *testing.T) {
		_, err := service.CreateStage(context.Background(), &protos.CreateStageRequest{
			OrganizationId: orgID.String(),
			CanvasId:       canvas.ID.String(),
			Name:           "test",
			RunTemplate:    &template,
		})

		s, ok := status.FromError(err)
		assert.True(t, ok)
		assert.Equal(t, codes.InvalidArgument, s.Code())
		assert.Equal(t, "invalid requester ID", s.Message())
	})

	t.Run("connection for source that does not exist -> error", func(t *testing.T) {
		_, err := service.CreateStage(context.Background(), &protos.CreateStageRequest{
			OrganizationId: orgID.String(),
			CanvasId:       canvas.ID.String(),
			Name:           "test",
			RunTemplate:    &template,
			RequesterId:    requesterID.String(),
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

	t.Run("stage with invalid connection filter expression variables -> error", func(t *testing.T) {
		_, err := service.CreateStage(context.Background(), &protos.CreateStageRequest{
			OrganizationId: orgID.String(),
			CanvasId:       canvas.ID.String(),
			Name:           "test",
			RequesterId:    requesterID.String(),
			RunTemplate:    &template,
			Connections: []*protos.Connection{
				{
					Name:           source.Name,
					Type:           protos.Connection_TYPE_EVENT_SOURCE,
					FilterOperator: protos.Connection_FILTER_OPERATOR_AND,
					Filters: []*protos.Connection_Filter{
						{
							Type: protos.Connection_FILTER_TYPE_EXPRESSION,
							Expression: &protos.Connection_ExpressionFilter{
								Expression: "true",
								Variables: []*protos.Connection_ExpressionFilter_Variable{
									{
										Name: "",
										Path: "test",
									},
								},
							},
						},
					},
				},
			},
		})

		s, ok := status.FromError(err)
		assert.True(t, ok)
		assert.Equal(t, codes.InvalidArgument, s.Code())
		assert.Equal(t, "invalid filter [0]: invalid variables: variable name is empty", s.Message())
	})

	t.Run("stage with connection with filters", func(t *testing.T) {
		res, err := service.CreateStage(context.Background(), &protos.CreateStageRequest{
			OrganizationId: orgID.String(),
			CanvasId:       canvas.ID.String(),
			Name:           "test",
			RunTemplate:    &template,
			RequesterId:    requesterID.String(),
			Connections: []*protos.Connection{
				{
					Name: source.Name,
					Type: protos.Connection_TYPE_EVENT_SOURCE,
					Filters: []*protos.Connection_Filter{
						{
							Type: protos.Connection_FILTER_TYPE_EXPRESSION,
							Expression: &protos.Connection_ExpressionFilter{
								Expression: "test == 12",
								Variables: []*protos.Connection_ExpressionFilter_Variable{
									{
										Name: "test",
										Path: "test",
									},
								},
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
		assert.Equal(t, orgID.String(), res.Stage.OrganizationId)
		assert.Equal(t, canvas.ID.String(), res.Stage.CanvasId)
		assert.Equal(t, "test", res.Stage.Name)
		assert.Equal(t, &template, res.Stage.RunTemplate)
		assert.Len(t, res.Stage.Connections, 1)
		assert.Len(t, res.Stage.Connections[0].Filters, 1)
		assert.Equal(t, protos.Connection_FILTER_OPERATOR_AND, res.Stage.Connections[0].FilterOperator)
	})

	t.Run("stage name already used -> error", func(t *testing.T) {
		_, err := service.CreateStage(context.Background(), &protos.CreateStageRequest{
			OrganizationId: orgID.String(),
			CanvasId:       canvas.ID.String(),
			Name:           "test",
			RequesterId:    requesterID.String(),
			RunTemplate:    &template,
		})

		s, ok := status.FromError(err)
		assert.True(t, ok)
		assert.Equal(t, codes.InvalidArgument, s.Code())
		assert.Equal(t, "name already used", s.Message())
	})
}

func Test__ListStageEvents(t *testing.T) {
	require.NoError(t, database.TruncateTables())

	service := NewDeliveryService(&encryptor.NoOpEncryptor{})
	orgID := uuid.New()
	userID := uuid.New()

	canvas, err := models.CreateCanvas(orgID, userID, "test")
	require.NoError(t, err)

	eventSource, err := canvas.CreateEventSource("gh", []byte("my-key"))
	require.NoError(t, err)

	template := models.RunTemplate{
		Type: models.RunTemplateTypeSemaphoreWorkflow,
		SemaphoreWorkflow: &models.SemaphoreWorkflowTemplate{
			ProjectID:    "demo-project",
			Branch:       "main",
			PipelineFile: ".semaphore/semaphore.yml",
		},
	}

	err = canvas.CreateStage("stage-1", userID, false, template, []models.StageConnection{})
	require.NoError(t, err)

	stage, err := models.FindStageByName(canvas.OrganizationID, canvas.ID, "stage-1")
	require.NoError(t, err)

	t.Run("no org ID -> error", func(t *testing.T) {
		_, err := service.ListStageEvents(context.Background(), &protos.ListStageEventsRequest{
			StageId:  uuid.New().String(),
			CanvasId: canvas.ID.String(),
		})

		s, ok := status.FromError(err)
		assert.True(t, ok)
		assert.Equal(t, codes.InvalidArgument, s.Code())
		assert.Equal(t, "invalid organization ID", s.Message())
	})

	t.Run("no canvas ID -> error", func(t *testing.T) {
		_, err := service.ListStageEvents(context.Background(), &protos.ListStageEventsRequest{
			StageId:        uuid.New().String(),
			OrganizationId: orgID.String(),
		})

		s, ok := status.FromError(err)
		assert.True(t, ok)
		assert.Equal(t, codes.InvalidArgument, s.Code())
		assert.Equal(t, "invalid canvas ID", s.Message())
	})

	t.Run("stage does not exist -> error", func(t *testing.T) {
		_, err := service.ListStageEvents(context.Background(), &protos.ListStageEventsRequest{
			StageId:        uuid.New().String(),
			OrganizationId: orgID.String(),
			CanvasId:       canvas.ID.String(),
		})

		s, ok := status.FromError(err)
		assert.True(t, ok)
		assert.Equal(t, codes.InvalidArgument, s.Code())
		assert.Equal(t, "stage not found", s.Message())
	})

	t.Run("stage with no stage events -> empty list", func(t *testing.T) {
		res, err := service.ListStageEvents(context.Background(), &protos.ListStageEventsRequest{
			StageId:        stage.ID.String(),
			CanvasId:       canvas.ID.String(),
			OrganizationId: orgID.String(),
		})

		require.NoError(t, err)
		require.NotNil(t, res)
		assert.Empty(t, res.Events)
	})

	t.Run("stage with stage events -> list", func(t *testing.T) {
		event, err := models.CreateEvent(eventSource.ID, models.SourceTypeEventSource, []byte(`{}`))
		require.NoError(t, err)

		_, err = models.CreateStageEvent(stage.ID, event)
		require.NoError(t, err)

		res, err := service.ListStageEvents(context.Background(), &protos.ListStageEventsRequest{
			OrganizationId: orgID.String(),
			CanvasId:       canvas.ID.String(),
			StageId:        stage.ID.String(),
		})

		require.NoError(t, err)
		require.NotNil(t, res)
		require.Len(t, res.Events, 1)
		assert.NotEmpty(t, res.Events[0].Id)
		assert.NotEmpty(t, res.Events[0].CreatedAt)
		assert.Equal(t, eventSource.ID.String(), res.Events[0].SourceId)
		assert.Equal(t, protos.Connection_TYPE_EVENT_SOURCE, res.Events[0].SourceType)
		assert.Equal(t, protos.StageEvent_PENDING, res.Events[0].State)
		assert.Empty(t, res.Events[0].ApprovedAt)
		assert.Empty(t, res.Events[0].ApprovedBy)
	})
}

func Test__ApproveStageEvent(t *testing.T) {
	require.NoError(t, database.TruncateTables())

	service := NewDeliveryService(&encryptor.NoOpEncryptor{})
	orgID := uuid.New()
	userID := uuid.New()

	canvas, err := models.CreateCanvas(orgID, userID, "test")
	require.NoError(t, err)

	eventSource, err := canvas.CreateEventSource("gh", []byte("my-key"))
	require.NoError(t, err)

	template := models.RunTemplate{
		Type: models.RunTemplateTypeSemaphoreWorkflow,
		SemaphoreWorkflow: &models.SemaphoreWorkflowTemplate{
			ProjectID:    "demo-project",
			Branch:       "main",
			PipelineFile: ".semaphore/semaphore.yml",
		},
	}

	err = canvas.CreateStage("stage-1", userID, true, template, []models.StageConnection{})
	require.NoError(t, err)
	stage, err := models.FindStageByName(canvas.OrganizationID, canvas.ID, "stage-1")
	require.NoError(t, err)

	e, err := models.CreateEvent(eventSource.ID, models.SourceTypeEventSource, []byte(`{}`))
	require.NoError(t, err)
	event, err := models.CreateStageEvent(stage.ID, e)
	require.NoError(t, err)

	t.Run("no org ID -> error", func(t *testing.T) {
		_, err := service.ApproveStageEvent(context.Background(), &protos.ApproveStageEventRequest{
			StageId:     uuid.New().String(),
			CanvasId:    canvas.ID.String(),
			EventId:     event.ID.String(),
			RequesterId: uuid.New().String(),
		})

		s, ok := status.FromError(err)
		assert.True(t, ok)
		assert.Equal(t, codes.InvalidArgument, s.Code())
		assert.Equal(t, "invalid organization ID", s.Message())
	})

	t.Run("no canvas ID -> error", func(t *testing.T) {
		_, err := service.ApproveStageEvent(context.Background(), &protos.ApproveStageEventRequest{
			StageId:        uuid.New().String(),
			OrganizationId: orgID.String(),
			EventId:        event.ID.String(),
			RequesterId:    uuid.New().String(),
		})

		s, ok := status.FromError(err)
		assert.True(t, ok)
		assert.Equal(t, codes.InvalidArgument, s.Code())
		assert.Equal(t, "invalid canvas ID", s.Message())
	})

	t.Run("stage does not exist -> error", func(t *testing.T) {
		_, err := service.ApproveStageEvent(context.Background(), &protos.ApproveStageEventRequest{
			OrganizationId: orgID.String(),
			CanvasId:       canvas.ID.String(),
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
		_, err := service.ApproveStageEvent(context.Background(), &protos.ApproveStageEventRequest{
			OrganizationId: orgID.String(),
			CanvasId:       canvas.ID.String(),
			StageId:        stage.ID.String(),
			EventId:        uuid.New().String(),
			RequesterId:    uuid.New().String(),
		})

		s, ok := status.FromError(err)
		assert.True(t, ok)
		assert.Equal(t, codes.InvalidArgument, s.Code())
		assert.Equal(t, "event not found", s.Message())
	})

	t.Run("stage with stage events -> list", func(t *testing.T) {
		res, err := service.ApproveStageEvent(context.Background(), &protos.ApproveStageEventRequest{
			OrganizationId: orgID.String(),
			CanvasId:       canvas.ID.String(),
			StageId:        stage.ID.String(),
			EventId:        event.ID.String(),
			RequesterId:    uuid.New().String(),
		})

		require.NoError(t, err)
		require.NotNil(t, res)
	})
}
