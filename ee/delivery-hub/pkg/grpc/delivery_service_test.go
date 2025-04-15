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
	userID := uuid.New()

	template := models.RunTemplate{
		Type: protos.RunTemplate_TYPE_SEMAPHORE_WORKFLOW.String(),
		SemaphoreWorkflow: &models.SemaphoreWorkflowTemplate{
			Project:      "demo-project",
			Branch:       "main",
			PipelineFile: ".semaphore/semaphore.yml",
		},
	}

	protoTemplate := protos.RunTemplate{
		Type: protos.RunTemplate_TYPE_SEMAPHORE_WORKFLOW,
		SemaphoreWorkflow: &protos.WorkflowTemplate{
			ProjectId:    "demo-project",
			Branch:       "main",
			PipelineFile: ".semaphore/semaphore.yml",
		},
	}

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

		eventSource, err := canvas.CreateEventSource("gh", []byte("my-key"))
		require.NoError(t, err)

		//
		// Connection only to the event source
		//
		err = canvas.CreateStage("stage-1", userID, false, template, []models.StageConnection{
			{
				SourceID:   eventSource.ID,
				SourceType: models.SourceTypeEventSource,
			},
		})

		require.NoError(t, err)
		stage1, err := models.FindStageByName(orgID, canvas.ID, "stage-1")
		require.NoError(t, err)

		//
		// Connection to the event source and also with the previous stage
		//
		err = canvas.CreateStage("stage-2", userID, false, template, []models.StageConnection{
			{
				SourceID:   eventSource.ID,
				SourceType: models.SourceTypeEventSource,
			},
			{
				SourceID:   stage1.ID,
				SourceType: models.SourceTypeStage,
			},
		})

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
		s1 := response.Canvas.Stages[0]
		assert.Equal(t, "stage-1", s1.Name)
		require.Len(t, s1.Connections, 1)
		assert.Equal(t, "gh", s1.Connections[0].Name)
		assert.Equal(t, protos.Connection_TYPE_EVENT_SOURCE, s1.Connections[0].Type)
		assert.Equal(t, &protoTemplate, s1.RunTemplate)

		//
		// Second stage just two connections: with a event source and another stage
		//
		s2 := response.Canvas.Stages[1]
		assert.Equal(t, "stage-2", s2.Name)
		require.Len(t, s2.Connections, 2)
		assert.Equal(t, "gh", s2.Connections[0].Name)
		assert.Equal(t, protos.Connection_TYPE_EVENT_SOURCE, s2.Connections[0].Type)
		assert.Equal(t, "stage-1", s2.Connections[1].Name)
		assert.Equal(t, protos.Connection_TYPE_STAGE, s2.Connections[1].Type)
		assert.Equal(t, &protoTemplate, s2.RunTemplate)
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
	requesterID := uuid.New()

	canvas, err := models.CreateCanvas(orgID, "test")
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

	t.Run("stage is created", func(t *testing.T) {
		res, err := service.CreateStage(context.Background(), &protos.CreateStageRequest{
			OrganizationId: orgID.String(),
			CanvasId:       canvas.ID.String(),
			Name:           "test",
			RunTemplate:    &template,
			RequesterId:    requesterID.String(),
		})

		require.NoError(t, err)
		require.NotNil(t, res)
		assert.NotNil(t, res.Stage.Id)
		assert.NotNil(t, res.Stage.CreatedAt)
		assert.Equal(t, orgID.String(), res.Stage.OrganizationId)
		assert.Equal(t, canvas.ID.String(), res.Stage.CanvasId)
		assert.Equal(t, "test", res.Stage.Name)
		assert.Empty(t, res.Stage.Connections)
		assert.Equal(t, &template, res.Stage.RunTemplate)
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

	canvas, err := models.CreateCanvas(orgID, "test")
	require.NoError(t, err)

	eventSource, err := canvas.CreateEventSource("gh", []byte("my-key"))
	require.NoError(t, err)

	template := models.RunTemplate{
		Type: protos.RunTemplate_TYPE_SEMAPHORE_WORKFLOW.String(),
		SemaphoreWorkflow: &models.SemaphoreWorkflowTemplate{
			Project:      "demo-project",
			Branch:       "main",
			PipelineFile: ".semaphore/semaphore.yml",
		},
	}

	err = canvas.CreateStage("stage-1", userID, false, template, []models.StageConnection{})
	require.NoError(t, err)

	stage, err := models.FindStageByName(canvas.OrganizationID, canvas.ID, "stage-1")
	require.NoError(t, err)

	t.Run("stage does not exist -> error", func(t *testing.T) {
		_, err := service.ListStageEvents(context.Background(), &protos.ListStageEventsRequest{
			StageId: uuid.New().String(),
		})

		s, ok := status.FromError(err)
		assert.True(t, ok)
		assert.Equal(t, codes.InvalidArgument, s.Code())
		assert.Equal(t, "stage not found", s.Message())
	})

	t.Run("stage with no stage events -> empty list", func(t *testing.T) {
		res, err := service.ListStageEvents(context.Background(), &protos.ListStageEventsRequest{
			StageId: stage.ID.String(),
		})

		require.NoError(t, err)
		require.NotNil(t, res)
		assert.Empty(t, res.Events)
	})

	t.Run("stage with stage events -> list", func(t *testing.T) {
		_, err = models.CreateStageEvent(stage.ID, eventSource.ID)
		require.NoError(t, err)

		res, err := service.ListStageEvents(context.Background(), &protos.ListStageEventsRequest{
			StageId: stage.ID.String(),
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

	canvas, err := models.CreateCanvas(orgID, "test")
	require.NoError(t, err)

	eventSource, err := canvas.CreateEventSource("gh", []byte("my-key"))
	require.NoError(t, err)

	template := models.RunTemplate{
		Type: protos.RunTemplate_TYPE_SEMAPHORE_WORKFLOW.String(),
		SemaphoreWorkflow: &models.SemaphoreWorkflowTemplate{
			Project:      "demo-project",
			Branch:       "main",
			PipelineFile: ".semaphore/semaphore.yml",
		},
	}

	err = canvas.CreateStage("stage-1", userID, true, template, []models.StageConnection{})
	require.NoError(t, err)
	stage, err := models.FindStageByName(canvas.OrganizationID, canvas.ID, "stage-1")
	require.NoError(t, err)

	event, err := models.CreateStageEvent(stage.ID, eventSource.ID)
	require.NoError(t, err)

	t.Run("stage does not exist -> error", func(t *testing.T) {
		_, err := service.ApproveStageEvent(context.Background(), &protos.ApproveStageEventRequest{
			StageId:     uuid.New().String(),
			EventId:     event.ID.String(),
			RequesterId: uuid.New().String(),
		})

		s, ok := status.FromError(err)
		assert.True(t, ok)
		assert.Equal(t, codes.InvalidArgument, s.Code())
		assert.Equal(t, "stage not found", s.Message())
	})

	t.Run("stage event does not exist -> error", func(t *testing.T) {
		_, err := service.ApproveStageEvent(context.Background(), &protos.ApproveStageEventRequest{
			StageId:     stage.ID.String(),
			EventId:     uuid.New().String(),
			RequesterId: uuid.New().String(),
		})

		s, ok := status.FromError(err)
		assert.True(t, ok)
		assert.Equal(t, codes.InvalidArgument, s.Code())
		assert.Equal(t, "event not found", s.Message())
	})

	t.Run("stage with stage events -> list", func(t *testing.T) {
		res, err := service.ApproveStageEvent(context.Background(), &protos.ApproveStageEventRequest{
			StageId:     stage.ID.String(),
			EventId:     event.ID.String(),
			RequesterId: uuid.New().String(),
		})

		require.NoError(t, err)
		require.NotNil(t, res)
	})
}
