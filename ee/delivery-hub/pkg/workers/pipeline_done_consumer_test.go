package workers

import (
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/renderedtext/go-tackle"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/database"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/models"
	protos "github.com/semaphoreio/semaphore/delivery-hub/pkg/protos/delivery"
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

	canvas, err := models.CreateCanvas(org, "test")
	require.NoError(t, err)

	source, err := canvas.CreateEventSource("gh", []byte("my-key"))
	require.NoError(t, err)

	template := models.RunTemplate{
		Type: protos.RunTemplate_TYPE_SEMAPHORE_WORKFLOW.String(),
		SemaphoreWorkflow: &models.SemaphoreWorkflowTemplate{
			Project:      "demo-project",
			Branch:       "main",
			PipelineFile: ".semaphore/run.yml",
		},
	}

	require.NoError(t, canvas.CreateStage("stage-1", user, false, template, []models.StageConnection{
		{
			SourceID: source.ID,
			Type:     protos.Connection_TYPE_EVENT_SOURCE.String(),
		},
	}))

	stage, err := models.FindStageByName(org, canvas.ID, "stage-1")
	require.NoError(t, err)

	go w.Start()
	defer w.Stop()

	t.Run("failed pipeline -> execution fails", func(t *testing.T) {
		//
		// Create execution
		//
		pipelineID := uuid.New().String()
		event, err := models.CreateStageEvent(stage.ID, source.ID)
		require.NoError(t, err)
		execution, err := models.CreateStageExecution(stage.ID, event.ID)
		require.NoError(t, err)
		require.NoError(t, execution.Start(pipelineID))

		//
		// Mock failed result and publish pipeline done message.
		//
		mockRegistry.PipelineService.MockPipelineResult(pplproto.Pipeline_FAILED)
		message := pplproto.PipelineEvent{PipelineId: pipelineID}
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
		}, time.Second, 100*time.Millisecond)
	})

	t.Run("passed pipeline -> execution passes", func(t *testing.T) {
		//
		// Create execution
		//
		pipelineID := uuid.New().String()
		event, err := models.CreateStageEvent(stage.ID, source.ID)
		require.NoError(t, err)
		execution, err := models.CreateStageExecution(stage.ID, event.ID)
		require.NoError(t, err)
		require.NoError(t, execution.Start(pipelineID))

		//
		// Mock failed result and publish pipeline done message.
		//
		mockRegistry.PipelineService.MockPipelineResult(pplproto.Pipeline_PASSED)
		message := pplproto.PipelineEvent{PipelineId: pipelineID}
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
		}, time.Second, 100*time.Millisecond)
	})
}
