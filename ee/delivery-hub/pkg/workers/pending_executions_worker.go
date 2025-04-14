package workers

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/logging"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/models"
	log "github.com/sirupsen/logrus"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"

	wfproto "github.com/semaphoreio/semaphore/delivery-hub/pkg/protos/plumber_w_f.workflow"
	repoproxyproto "github.com/semaphoreio/semaphore/delivery-hub/pkg/protos/repo_proxy"
)

type PendingExecutionsWorker struct {
	RepoProxyURL string
}

func (w *PendingExecutionsWorker) Start() {
	for {
		err := w.Tick()
		if err != nil {
			log.Errorf("Error processing pending events: %v", err)
		}

		time.Sleep(time.Second)
	}
}

func (w *PendingExecutionsWorker) Tick() error {
	executions, err := models.ListPendingStageExecutions()
	if err != nil {
		return fmt.Errorf("error listing pending stage executions: %v", err)
	}

	for _, execution := range executions {
		stage, err := models.FindStageByID(execution.StageID)
		if err != nil {
			return fmt.Errorf("error finding stage %s: %v", execution.StageID, err)
		}

		logger := logging.ForStage(stage)
		if err := w.ProcessExecution(logger, stage, execution); err != nil {
			return fmt.Errorf("error processing execution %s: %v", execution.ID, err)
		}
	}

	return nil
}

// TODO
// There is an issue here where, if we are having issues updating the state of the execution in the database,
// we might end up creating more executions than we should.
func (w *PendingExecutionsWorker) ProcessExecution(logger *log.Entry, stage *models.Stage, execution models.StageExecution) error {
	executionID, err := w.StartExecution(logger, stage, stage.RunTemplate.Data())
	if err != nil {
		return fmt.Errorf("error starting execution: %v", err)
	}

	err = execution.Start(executionID)
	if err != nil {
		return fmt.Errorf("error moving execution to started state: %v", err)
	}

	logger.Infof("Started execution %s", executionID)

	return nil
}

func (w *PendingExecutionsWorker) StartExecution(logger *log.Entry, stage *models.Stage, runTemplate models.RunTemplate) (string, error) {
	if runTemplate.SemaphoreWorkflow != nil {
		return w.StartSemaphoreWorkflow(logger, stage, runTemplate.SemaphoreWorkflow)
	}

	// TODO: retry and give up mechanism
	// TODO: handle other types of run template types.

	return "", fmt.Errorf("unknown run template type")
}

func (w *PendingExecutionsWorker) StartSemaphoreWorkflow(logger *log.Entry, stage *models.Stage, template *models.SemaphoreWorkflowTemplate) (string, error) {
	conn, err := grpc.NewClient(w.RepoProxyURL, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		return "", fmt.Errorf("error connecting to repo proxy API: %v", err)
	}

	defer conn.Close()

	client := repoproxyproto.NewRepoProxyServiceClient(conn)
	res, err := client.Create(context.TODO(), &repoproxyproto.CreateRequest{
		ProjectId:      template.Project,
		RequestToken:   uuid.New().String(),
		RequesterId:    stage.CreatedBy.String(),
		DefinitionFile: template.PipelineFile,
		TriggeredBy:    wfproto.TriggeredBy_API,
		Git: &repoproxyproto.CreateRequest_Git{
			Reference: "refs/heads/" + template.Branch,
		},
	})

	if err != nil {
		return "", fmt.Errorf("error calling repo proxy API: %v", err)
	}

	logger.Infof("Semaphore workflow created: workflow=%s pipeline=%s", res.WorkflowId, res.PipelineId)
	return res.PipelineId, nil
}
