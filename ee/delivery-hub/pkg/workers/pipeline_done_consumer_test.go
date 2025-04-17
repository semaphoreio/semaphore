package workers

import (
	"encoding/json"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/renderedtext/go-tackle"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/database"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/events"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/models"
	pplproto "github.com/semaphoreio/semaphore/delivery-hub/pkg/protos/plumber.pipeline"
	"github.com/semaphoreio/semaphore/delivery-hub/test/grpcmock"
	"github.com/stretchr/testify/require"
	"google.golang.org/protobuf/proto"
)

func Test__PipelineDoneConsumer(t *testing.T) {
	mockRegistry, err := grpcmock.Start()
	require.NoError(t, err)
	require.NoError(t, database.TruncateTables())

	amqpURL := "amqp://guest:guest@rabbitmq:5672"
	w := NewPipelineDoneConsumer(amqpURL, "0.0.0.0:50052")

	org := uuid.New()
	user := uuid.New()

	canvas, err := models.CreateCanvas(org, user, "test")
	require.NoError(t, err)

	source, err := canvas.CreateEventSource("gh", []byte("my-key"))
	require.NoError(t, err)

	template := models.RunTemplate{
		Type: models.RunTemplateTypeSemaphoreWorkflow,
		SemaphoreWorkflow: &models.SemaphoreWorkflowTemplate{
			ProjectID:    "demo-project",
			Branch:       "main",
			PipelineFile: ".semaphore/run.yml",
		},
	}

	require.NoError(t, canvas.CreateStage("stage-1", user, false, template, []models.StageConnection{
		{
			SourceID:   source.ID,
			SourceType: models.SourceTypeEventSource,
		},
	}))

	stage, err := models.FindStageByName(org, canvas.ID, "stage-1")
	require.NoError(t, err)

	go w.Start()
	defer w.Stop()

	//
	// give the worker a few milliseconds to start before we start running the tests
	//
	time.Sleep(100 * time.Millisecond)

	t.Run("failed pipeline -> execution fails", func(t *testing.T) {
		require.NoError(t, database.Conn().Exec(`truncate table events`).Error)

		//
		// Create execution
		//
		workflowID := uuid.New().String()
		ev, err := models.CreateEvent(source.ID, models.SourceTypeEventSource, []byte(`{}`))
		require.NoError(t, err)
		event, err := models.CreateStageEvent(stage.ID, ev)
		require.NoError(t, err)
		execution, err := models.CreateStageExecution(stage.ID, event.ID)
		require.NoError(t, err)
		require.NoError(t, execution.Start(workflowID))

		//
		// Mock failed result and publish pipeline done message.
		//
		mockRegistry.PipelineService.MockPipelineResult(pplproto.Pipeline_FAILED)
		mockRegistry.PipelineService.MockWorkflow(workflowID)
		message := pplproto.PipelineEvent{PipelineId: uuid.New().String()}
		body, err := proto.Marshal(&message)
		require.NoError(t, err)
		require.NoError(t, tackle.PublishMessage(&tackle.PublishParams{
			AmqpURL:    amqpURL,
			RoutingKey: "done",
			Exchange:   "pipeline_state_exchange",
			Body:       body,
		}))

		//
		// Verify execution eventually goes to the finished state, with result = failed.
		//
		require.Eventually(t, func() bool {
			e, err := models.FindExecutionByID(execution.ID)
			if err != nil {
				return false
			}

			return e.State == models.StageExecutionFinished && e.Result == models.StageExecutionResultFailed
		}, 5*time.Second, 200*time.Millisecond)

		//
		// Verify that new pending event for stage completion is created.
		//
		list, err := models.ListEventsBySourceID(stage.ID)
		require.NoError(t, err)
		require.Len(t, list, 1)
		require.Equal(t, list[0].State, models.StageEventPending)
		require.Equal(t, list[0].SourceID, stage.ID)
		require.Equal(t, list[0].SourceType, models.SourceTypeStage)
		e, err := unmarshalCompletionEvent(list[0].Raw)
		require.NoError(t, err)
		require.Equal(t, events.StageExecutionCompletionType, e.Type)
		require.Equal(t, stage.ID.String(), e.Stage.ID)
		require.Equal(t, execution.ID.String(), e.StageExecution.ID)
		require.Equal(t, models.StageExecutionResultFailed, e.StageExecution.Result)
		require.NotEmpty(t, e.StageExecution.CreatedAt)
		require.NotEmpty(t, e.StageExecution.StartedAt)
		require.NotEmpty(t, e.StageExecution.FinishedAt)
	})

	t.Run("passed pipeline -> execution passes", func(t *testing.T) {
		require.NoError(t, database.Conn().Exec(`truncate table events`).Error)

		//
		// Create execution
		//
		workflowID := uuid.New().String()
		ev, err := models.CreateEvent(source.ID, models.SourceTypeEventSource, []byte(`{}`))
		require.NoError(t, err)
		event, err := models.CreateStageEvent(stage.ID, ev)
		require.NoError(t, err)
		execution, err := models.CreateStageExecution(stage.ID, event.ID)
		require.NoError(t, err)
		require.NoError(t, execution.Start(workflowID))

		//
		// Mock failed result and publish pipeline done message.
		//
		mockRegistry.PipelineService.MockPipelineResult(pplproto.Pipeline_PASSED)
		mockRegistry.PipelineService.MockWorkflow(workflowID)
		message := pplproto.PipelineEvent{PipelineId: uuid.New().String()}
		body, err := proto.Marshal(&message)
		require.NoError(t, err)
		require.NoError(t, tackle.PublishMessage(&tackle.PublishParams{
			AmqpURL:    amqpURL,
			RoutingKey: "done",
			Exchange:   "pipeline_state_exchange",
			Body:       body,
		}))

		//
		// Verify execution eventually goes to the finished state, with result = failed.
		//
		require.Eventually(t, func() bool {
			e, err := models.FindExecutionByID(execution.ID)
			if err != nil {
				return false
			}

			return e.State == models.StageExecutionFinished && e.Result == models.StageExecutionResultPassed
		}, 5*time.Second, 200*time.Millisecond)

		//
		// Verify that new pending event for stage completion is created with proper result.
		//
		list, err := models.ListEventsBySourceID(stage.ID)
		require.NoError(t, err)
		require.Len(t, list, 1)
		require.Equal(t, list[0].State, models.StageEventPending)
		require.Equal(t, list[0].SourceID, stage.ID)
		require.Equal(t, list[0].SourceType, models.SourceTypeStage)
		e, err := unmarshalCompletionEvent(list[0].Raw)
		require.NoError(t, err)
		require.Equal(t, events.StageExecutionCompletionType, e.Type)
		require.Equal(t, stage.ID.String(), e.Stage.ID)
		require.Equal(t, execution.ID.String(), e.StageExecution.ID)
		require.Equal(t, models.StageExecutionResultPassed, e.StageExecution.Result)
		require.NotEmpty(t, e.StageExecution.CreatedAt)
		require.NotEmpty(t, e.StageExecution.StartedAt)
		require.NotEmpty(t, e.StageExecution.FinishedAt)
	})
}

func unmarshalCompletionEvent(raw []byte) (*events.StageExecutionCompletion, error) {
	e := events.StageExecutionCompletion{}
	err := json.Unmarshal(raw, &e)
	if err != nil {
		return nil, err
	}

	return &e, nil
}
