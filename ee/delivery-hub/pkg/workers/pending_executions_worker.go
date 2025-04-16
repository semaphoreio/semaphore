package workers

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/logging"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/models"
	log "github.com/sirupsen/logrus"
	"google.golang.org/genproto/googleapis/rpc/code"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"

	schedulerproto "github.com/semaphoreio/semaphore/delivery-hub/pkg/protos/periodic_scheduler"
	wfproto "github.com/semaphoreio/semaphore/delivery-hub/pkg/protos/plumber_w_f.workflow"
	repoproxyproto "github.com/semaphoreio/semaphore/delivery-hub/pkg/protos/repo_proxy"
)

type PendingExecutionsWorker struct {
	RepoProxyURL string
	SchedulerURL string
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

// TODO: implement some retry and give up mechanism
func (w *PendingExecutionsWorker) StartExecution(logger *log.Entry, stage *models.Stage, runTemplate models.RunTemplate) (string, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	switch runTemplate.Type {
	case models.RunTemplateTypeSemaphoreWorkflow:
		return w.StartSemaphoreWorkflow(ctx, logger, stage, runTemplate.SemaphoreWorkflow)
	case models.RunTemplateTypeSemaphoreTask:
		return w.TriggerSemaphoreTask(ctx, logger, stage, runTemplate.SemaphoreTask)
	default:
		return "", fmt.Errorf("unknown run template type")
	}

}

func (w *PendingExecutionsWorker) StartSemaphoreWorkflow(ctx context.Context, l *log.Entry, s *models.Stage, t *models.SemaphoreWorkflowTemplate) (string, error) {
	conn, err := grpc.NewClient(w.RepoProxyURL, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		return "", fmt.Errorf("error connecting to repo proxy API: %v", err)
	}

	defer conn.Close()

	// TODO: call RBAC API to check if s.CreatedBy can create workflow

	client := repoproxyproto.NewRepoProxyServiceClient(conn)
	res, err := client.Create(ctx, &repoproxyproto.CreateRequest{
		ProjectId:      t.ProjectID,
		RequestToken:   uuid.New().String(),
		RequesterId:    s.CreatedBy.String(),
		DefinitionFile: t.PipelineFile,
		TriggeredBy:    wfproto.TriggeredBy_API,
		Git: &repoproxyproto.CreateRequest_Git{
			Reference: "refs/heads/" + t.Branch,
		},
	})

	if err != nil {
		return "", fmt.Errorf("error calling repo proxy API: %v", err)
	}

	l.Infof("Semaphore workflow created: workflow=%s", res.WorkflowId)
	return res.WorkflowId, nil
}

func (w *PendingExecutionsWorker) TriggerSemaphoreTask(ctx context.Context, l *log.Entry, s *models.Stage, t *models.SemaphoreTaskTemplate) (string, error) {
	conn, err := grpc.NewClient(w.SchedulerURL, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		return "", fmt.Errorf("error connecting to task API: %v", err)
	}

	defer conn.Close()

	// TODO: call RBAC API to check if s.CreatedBy can create workflow

	client := schedulerproto.NewPeriodicServiceClient(conn)
	res, err := client.RunNow(context.Background(), &schedulerproto.RunNowRequest{
		Id:              t.TaskID,
		Requester:       s.CreatedBy.String(),
		Branch:          t.Branch,
		PipelineFile:    t.PipelineFile,
		ParameterValues: buildParameters(t.Parameters),
	})

	if err != nil {
		return "", fmt.Errorf("error calling task API: %v", err)
	}

	if res.Status.Code != code.Code_OK {
		return "", fmt.Errorf("task API returned %v: %s", res.Status.Code, res.Status.Message)
	}

	l.Infof("Semaphore task triggered - workflow=%s", res.Trigger.ScheduledWorkflowId)
	return res.Trigger.ScheduledWorkflowId, nil
}

func buildParameters(parameters map[string]string) []*schedulerproto.ParameterValue {
	var parameterValues []*schedulerproto.ParameterValue

	for key, value := range parameters {
		parameterValues = append(parameterValues, &schedulerproto.ParameterValue{
			Name:  key,
			Value: value,
		})
	}

	return parameterValues
}
