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
	"github.com/semaphoreio/semaphore/delivery-hub/test/support"
	testconsumer "github.com/semaphoreio/semaphore/delivery-hub/test/test_consumer"
	"github.com/stretchr/testify/require"
	"google.golang.org/protobuf/proto"
)

const ExecutionFinishedRoutingKey = "execution-finished"

func Test__PipelineDoneConsumer(t *testing.T) {
	r := support.SetupWithOptions(t, support.SetupOptions{Source: true, Stage: true, Grpc: true})

	amqpURL := "amqp://guest:guest@rabbitmq:5672"
	w := NewPipelineDoneConsumer(amqpURL, "0.0.0.0:50052")

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
		execution := support.CreateExecution(t, r.Source, r.Stage)
		require.NoError(t, execution.Start(workflowID))

		testconsumer := testconsumer.New(amqpURL, ExecutionFinishedRoutingKey)
		testconsumer.Start()
		defer testconsumer.Stop()

		//
		// Mock failed result and publish pipeline done message.
		//
		r.Grpc.PipelineService.MockPipelineResult(pplproto.Pipeline_FAILED)
		r.Grpc.PipelineService.MockWorkflow(workflowID)
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
		list, err := models.ListEventsBySourceID(r.Stage.ID)
		require.NoError(t, err)
		require.Len(t, list, 1)
		require.Equal(t, list[0].State, models.StageEventPending)
		require.Equal(t, list[0].SourceID, r.Stage.ID)
		require.Equal(t, list[0].SourceType, models.SourceTypeStage)
		e, err := unmarshalCompletionEvent(list[0].Raw)
		require.NoError(t, err)
		require.Equal(t, events.StageExecutionCompletionType, e.Type)
		require.Equal(t, r.Stage.ID.String(), e.Stage.ID)
		require.Equal(t, execution.ID.String(), e.Execution.ID)
		require.Equal(t, models.StageExecutionResultFailed, e.Execution.Result)
		require.NotEmpty(t, e.Execution.CreatedAt)
		require.NotEmpty(t, e.Execution.StartedAt)
		require.NotEmpty(t, e.Execution.FinishedAt)
		require.True(t, testconsumer.HasReceivedMessage())
	})

	t.Run("passed pipeline -> execution passes", func(t *testing.T) {
		require.NoError(t, database.Conn().Exec(`truncate table events`).Error)

		//
		// Create execution
		//
		workflowID := uuid.New().String()
		execution := support.CreateExecution(t, r.Source, r.Stage)
		require.NoError(t, execution.Start(workflowID))

		testconsumer := testconsumer.New(amqpURL, ExecutionFinishedRoutingKey)
		testconsumer.Start()
		defer testconsumer.Stop()

		//
		// Mock failed result and publish pipeline done message.
		//
		r.Grpc.PipelineService.MockPipelineResult(pplproto.Pipeline_PASSED)
		r.Grpc.PipelineService.MockWorkflow(workflowID)
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
		list, err := models.ListEventsBySourceID(r.Stage.ID)
		require.NoError(t, err)
		require.Len(t, list, 1)
		require.Equal(t, list[0].State, models.StageEventPending)
		require.Equal(t, list[0].SourceID, r.Stage.ID)
		require.Equal(t, list[0].SourceType, models.SourceTypeStage)
		e, err := unmarshalCompletionEvent(list[0].Raw)
		require.NoError(t, err)
		require.Equal(t, events.StageExecutionCompletionType, e.Type)
		require.Equal(t, r.Stage.ID.String(), e.Stage.ID)
		require.Equal(t, execution.ID.String(), e.Execution.ID)
		require.Equal(t, models.StageExecutionResultPassed, e.Execution.Result)
		require.NotEmpty(t, e.Execution.CreatedAt)
		require.NotEmpty(t, e.Execution.StartedAt)
		require.NotEmpty(t, e.Execution.FinishedAt)
		require.True(t, testconsumer.HasReceivedMessage())
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
