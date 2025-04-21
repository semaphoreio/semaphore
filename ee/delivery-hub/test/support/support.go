package support

import (
	"testing"

	"github.com/google/uuid"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/database"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/models"
	protos "github.com/semaphoreio/semaphore/delivery-hub/pkg/protos/delivery"
	"github.com/semaphoreio/semaphore/delivery-hub/test/grpcmock"
	"github.com/stretchr/testify/require"
)

type ResourceRegistry struct {
	Org    uuid.UUID
	User   uuid.UUID
	Canvas *models.Canvas
	Source *models.EventSource
	Stage  *models.Stage
	Grpc   *grpcmock.ServiceRegistry
}

type SetupOptions struct {
	Source bool
	Stage  bool
	Grpc   bool
}

func Setup(t *testing.T) *ResourceRegistry {
	return SetupWithOptions(t, SetupOptions{
		Source: true,
		Stage:  true,
	})
}

func SetupWithOptions(t *testing.T, options SetupOptions) *ResourceRegistry {
	require.NoError(t, database.TruncateTables())

	r := ResourceRegistry{
		Org:  uuid.New(),
		User: uuid.New(),
	}

	var err error
	r.Canvas, err = models.CreateCanvas(r.Org, r.User, "test")
	require.NoError(t, err)

	if options.Source {
		r.Source, err = r.Canvas.CreateEventSource("gh", []byte("my-key"))
		require.NoError(t, err)
	}

	if options.Stage {
		err = r.Canvas.CreateStage("stage-1", r.User.String(), true, RunTemplate(), []models.StageConnection{})
		require.NoError(t, err)
		r.Stage, err = r.Canvas.FindStageByName("stage-1")
		require.NoError(t, err)
	}

	if options.Grpc {
		r.Grpc, err = grpcmock.Start()
		require.NoError(t, err)
	}

	return &r
}

func CreateStageEvent(t *testing.T, source *models.EventSource, stage *models.Stage) *models.StageEvent {
	event, err := models.CreateEvent(source.ID, source.Name, models.SourceTypeEventSource, []byte(`{}`))
	require.NoError(t, err)
	stageEvent, err := models.CreateStageEvent(stage.ID, event)
	require.NoError(t, err)
	return stageEvent
}

func CreateExecution(t *testing.T, source *models.EventSource, stage *models.Stage) *models.StageExecution {
	return CreateExecutionWithData(t, source, stage, []byte(`{}`))
}

func CreateExecutionWithData(t *testing.T, source *models.EventSource, stage *models.Stage, data []byte) *models.StageExecution {
	e, err := models.CreateEvent(source.ID, source.Name, models.SourceTypeEventSource, data)
	require.NoError(t, err)
	event, err := models.CreateStageEvent(stage.ID, e)
	require.NoError(t, err)
	execution, err := models.CreateStageExecution(stage.ID, event.ID)
	require.NoError(t, err)
	return execution
}

func RunTemplate() models.RunTemplate {
	return models.RunTemplate{
		Type: models.RunTemplateTypeSemaphore,
		Semaphore: &models.SemaphoreRunTemplate{
			ProjectID:    "demo-project",
			Branch:       "main",
			PipelineFile: ".semaphore/semaphore.yml",
			Parameters:   map[string]string{},
		},
	}
}

func WorkflowRunTemplate() models.RunTemplate {
	return RunTemplate()
}

func TaskRunTemplate() models.RunTemplate {
	return models.RunTemplate{
		Type: models.RunTemplateTypeSemaphore,
		Semaphore: &models.SemaphoreRunTemplate{
			ProjectID:    "demo-project",
			TaskID:       "demo-task",
			Branch:       "main",
			PipelineFile: ".semaphore/run.yml",
			Parameters: map[string]string{
				"PARAM_1": "VALUE_1",
				"PARAM_2": "VALUE_2",
			},
		},
	}
}

func ProtoRunTemplate() *protos.RunTemplate {
	return &protos.RunTemplate{
		Type: protos.RunTemplate_TYPE_SEMAPHORE,
		Semaphore: &protos.SemaphoreRunTemplate{
			ProjectId:    "test",
			Branch:       "main",
			PipelineFile: ".semaphore/semaphore.yml",
			Parameters:   map[string]string{},
		},
	}
}
