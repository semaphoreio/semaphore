package workers

import (
	"encoding/json"
	"slices"
	"testing"

	"github.com/google/uuid"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/config"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/events"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/jwt"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/models"
	schedulepb "github.com/semaphoreio/semaphore/delivery-hub/pkg/protos/periodic_scheduler"
	"github.com/semaphoreio/semaphore/delivery-hub/test/support"
	testconsumer "github.com/semaphoreio/semaphore/delivery-hub/test/test_consumer"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

const ExecutionStartedRoutingKey = "execution-started"

func Test__PendingExecutionsWorker(t *testing.T) {
	r := support.SetupWithOptions(t, support.SetupOptions{Source: true, Stage: true, Grpc: true})
	w := PendingExecutionsWorker{
		RepoProxyURL: "0.0.0.0:50052",
		SchedulerURL: "0.0.0.0:50052",
		JwtSigner:    jwt.NewSigner("test"),
	}
	amqpURL, _ := config.RabbitMQURL()

	t.Run("semaphore workflow is created", func(t *testing.T) {
		//
		// Create stage that creates Semaphore workflows.
		//
		require.NoError(t, r.Canvas.CreateStage("stage-wf", r.User.String(), false, support.RunTemplate(), []models.StageConnection{
			{
				SourceID:   r.Source.ID,
				SourceType: models.SourceTypeEventSource,
			},
		}))

		stage, err := r.Canvas.FindStageByName("stage-wf")
		require.NoError(t, err)

		testconsumer := testconsumer.New(amqpURL, ExecutionStartedRoutingKey)
		testconsumer.Start()
		defer testconsumer.Stop()

		//
		// Create pending execution.
		//
		execution := support.CreateExecution(t, r.Source, stage)

		//
		// Trigger the worker, and verify that request to repo proxy was sent,
		// and that execution was moved to 'started' state.
		//
		err = w.Tick()
		require.NoError(t, err)
		execution, err = stage.FindExecutionByID(execution.ID)
		require.NoError(t, err)
		assert.Equal(t, models.StageExecutionStarted, execution.State)
		assert.NotEmpty(t, execution.ReferenceID)
		assert.NotEmpty(t, execution.StartedAt)
		assert.True(t, testconsumer.HasReceivedMessage())
		repoProxyReq := r.Grpc.RepoProxyService.GetLastCreateRequest()
		require.NotNil(t, repoProxyReq)
		assert.Equal(t, "demo-project", repoProxyReq.ProjectId)
		assert.Equal(t, ".semaphore/semaphore.yml", repoProxyReq.DefinitionFile)
		assert.Equal(t, stage.CreatedBy.String(), repoProxyReq.RequesterId)
		assert.Equal(t, "refs/heads/main", repoProxyReq.Git.Reference)
	})

	t.Run("semaphore task is triggered with simple parameters", func(t *testing.T) {
		//
		// Create stage that trigger Semaphore task.
		//
		require.NoError(t, r.Canvas.CreateStage("stage-task", r.User.String(), false, support.TaskRunTemplate(), []models.StageConnection{
			{
				SourceID:   r.Source.ID,
				SourceType: models.SourceTypeEventSource,
			},
		}))

		stage, err := r.Canvas.FindStageByName("stage-task")
		require.NoError(t, err)

		//
		// Create pending execution.
		//
		e, err := models.CreateEvent(r.Source.ID, r.Source.Name, models.SourceTypeEventSource, []byte(`{}`))
		require.NoError(t, err)
		event, err := models.CreateStageEvent(stage.ID, e)
		require.NoError(t, err)
		execution, err := models.CreateStageExecution(stage.ID, event.ID)
		require.NoError(t, err)

		testconsumer := testconsumer.New(amqpURL, ExecutionStartedRoutingKey)
		testconsumer.Start()
		defer testconsumer.Stop()

		//
		// Trigger the worker, and verify that request to scheduler was sent,
		// and that execution was moved to 'started' state.
		//
		err = w.Tick()
		require.NoError(t, err)
		execution, err = stage.FindExecutionByID(execution.ID)
		require.NoError(t, err)
		assert.Equal(t, models.StageExecutionStarted, execution.State)
		assert.NotEmpty(t, execution.ReferenceID)
		assert.NotEmpty(t, execution.StartedAt)
		assert.True(t, testconsumer.HasReceivedMessage())

		req := r.Grpc.SchedulerService.GetLastRunNowRequest()
		require.NotNil(t, req)
		assert.Equal(t, "demo-task", req.Id)
		assert.Equal(t, "main", req.Branch)
		assert.Equal(t, ".semaphore/run.yml", req.PipelineFile)
		assert.Equal(t, stage.CreatedBy.String(), req.Requester)
		assertParameters(t, req, execution, map[string]string{
			"PARAM_1": "VALUE_1",
			"PARAM_2": "VALUE_2",
		})
	})

	t.Run("semaphore task with resolved parameters is triggered", func(t *testing.T) {
		//
		// Create stage that trigger Semaphore task.
		//
		template := support.TaskRunTemplate()
		template.Semaphore.Parameters = map[string]string{
			"REF":             "${{ self.Conn('gh').ref }}",
			"REF_TYPE":        "${{ self.Conn('gh').ref_type }}",
			"STAGE_1_VERSION": "${{ self.Conn('stage-1').outputs.version }}",
		}

		require.NoError(t, r.Canvas.CreateStage("stage-task-2", r.User.String(), false, template, []models.StageConnection{
			{
				SourceID:   r.Source.ID,
				SourceName: r.Source.Name,
				SourceType: models.SourceTypeEventSource,
			},
			{
				SourceID:   r.Stage.ID,
				SourceName: r.Stage.Name,
				SourceType: models.SourceTypeStage,
			},
		}))

		stage, err := r.Canvas.FindStageByName("stage-task-2")
		require.NoError(t, err)

		//
		// Since we use the outputs of a stage in the template for the execution,
		// we need a previous event for that stage to be available, so we create it here.
		//
		data := createStageCompletionEvent(t, r, map[string]string{"version": "1.0.0"})
		_, err = models.CreateEvent(r.Stage.ID, r.Stage.Name, models.SourceTypeStage, data)
		require.NoError(t, err)

		//
		// Create pending execution for a new event source event.
		//
		e, err := models.CreateEvent(r.Source.ID, r.Source.Name, models.SourceTypeEventSource, []byte(`{"ref_type":"branch","ref":"refs/heads/test"}`))
		require.NoError(t, err)
		event, err := models.CreateStageEvent(stage.ID, e)
		require.NoError(t, err)
		execution, err := models.CreateStageExecution(stage.ID, event.ID)
		require.NoError(t, err)

		testconsumer := testconsumer.New(amqpURL, ExecutionStartedRoutingKey)
		testconsumer.Start()
		defer testconsumer.Stop()

		//
		// Trigger the worker, and verify that request to scheduler was sent,
		// and that execution was moved to 'started' state.
		//
		err = w.Tick()
		require.NoError(t, err)
		execution, err = stage.FindExecutionByID(execution.ID)
		require.NoError(t, err)
		assert.Equal(t, models.StageExecutionStarted, execution.State)
		assert.NotEmpty(t, execution.ReferenceID)
		assert.NotEmpty(t, execution.StartedAt)
		assert.True(t, testconsumer.HasReceivedMessage())

		req := r.Grpc.SchedulerService.GetLastRunNowRequest()
		require.NotNil(t, req)
		assert.Equal(t, "demo-task", req.Id)
		assert.Equal(t, "main", req.Branch)
		assert.Equal(t, ".semaphore/run.yml", req.PipelineFile)
		assert.Equal(t, stage.CreatedBy.String(), req.Requester)
		assertParameters(t, req, execution, map[string]string{
			"REF":             "refs/heads/test",
			"REF_TYPE":        "branch",
			"STAGE_1_VERSION": "1.0.0",
		})
	})
}

func assertParameters(t *testing.T, req *schedulepb.RunNowRequest, execution *models.StageExecution, parameters map[string]string) {
	all := map[string]string{
		"SEMAPHORE_STAGE_ID":           execution.StageID.String(),
		"SEMAPHORE_STAGE_EXECUTION_ID": execution.ID.String(),
	}

	for k, v := range parameters {
		all[k] = v
	}

	assert.Len(t, req.ParameterValues, len(all)+1)
	for name, value := range all {
		assert.True(t, slices.ContainsFunc(req.ParameterValues, func(v *schedulepb.ParameterValue) bool {
			return v.Name == name && v.Value == value
		}))
	}

	assert.True(t, slices.ContainsFunc(req.ParameterValues, func(v *schedulepb.ParameterValue) bool {
		return v.Name == "SEMAPHORE_STAGE_EXECUTION_TOKEN" && v.Value != ""
	}))
}

func createStageCompletionEvent(t *testing.T, r *support.ResourceRegistry, outputs map[string]string) []byte {
	o, err := json.Marshal(outputs)
	require.NoError(t, err)
	e, err := events.NewStageExecutionCompletion(&models.StageExecution{
		ID:      uuid.New(),
		StageID: r.Stage.ID,
		Result:  models.StageExecutionResultPassed,
		Outputs: o,
	})

	require.NoError(t, err)
	data, err := json.Marshal(e)
	require.NoError(t, err)

	return data
}
