package workers

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/renderedtext/go-tackle"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/events"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/logging"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/models"
	pplproto "github.com/semaphoreio/semaphore/delivery-hub/pkg/protos/plumber.pipeline"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/retry"
	log "github.com/sirupsen/logrus"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
	"google.golang.org/protobuf/proto"
	"gorm.io/gorm"
)

type PipelineDoneConsumer struct {
	Consumer       *tackle.Consumer
	RabbitMQURL    string
	PipelineAPIURL string
}

func NewPipelineDoneConsumer(rabbitMQURL, pipelineAPIURL string) *PipelineDoneConsumer {
	return &PipelineDoneConsumer{
		RabbitMQURL:    rabbitMQURL,
		PipelineAPIURL: pipelineAPIURL,
		Consumer:       tackle.NewConsumer(),
	}
}

func (c *PipelineDoneConsumer) Start() error {
	options := tackle.Options{
		URL:            c.RabbitMQURL,
		Service:        "delivery_hub",
		ConnectionName: "delivery_hub",
		RemoteExchange: "pipeline_state_exchange",
		RoutingKey:     "done",
	}

	err := retry.WithConstantWait("RabbitMQ connection", 5, time.Second, func() error {
		return c.Consumer.Start(&options, c.Consume)
	})

	if err != nil {
		return fmt.Errorf("error starting consumer: %v", err)
	}

	return nil
}

func (c *PipelineDoneConsumer) Stop() {
	c.Consumer.Stop()
}

func (c *PipelineDoneConsumer) Consume(delivery tackle.Delivery) error {
	pipelineEvent := &pplproto.PipelineEvent{}
	err := proto.Unmarshal(delivery.Body(), pipelineEvent)
	if err != nil {
		return err
	}

	ID := pipelineEvent.PipelineId
	log.Infof("Received message for %s", ID)

	//
	// Not all pipelines are related to stage executions, so we
	// check if there are is a stage execution associated with this pipeline first.
	//
	execution, err := models.FindExecutionByReference(ID)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			log.Infof("No execution for %s - ignoring", ID)
			return nil
		}
	}

	//
	// The message doesn't contain the result of the pipeline,
	// so we need to go to use the pipeline API for that,
	// and map the pipeline result to a stage execution result.
	//
	logger := logging.ForExecution(execution)
	result, err := c.findPipelineResult(logger, ID)
	if err != nil {
		logger.Errorf("Error finding pipeline result: %v", err)
		return err
	}

	//
	// Update the stage execution accordingly.
	//
	if err := execution.Finish(result); err != nil {
		logger.Errorf("Error updating execution state: %v", err)
		return err
	}

	logger.Infof("Execution state updated: %s", result)

	//
	// Lastly, since the stage for this execution might be connected to other stages,
	// we create a new event for the completion of this stage.
	//
	if err := c.createStageCompletionEvent(logger, execution, result); err != nil {
		logger.Errorf("Error creating stage completion event: %v", err)
		return err
	}

	return nil
}

func (c *PipelineDoneConsumer) findPipelineResult(logger *log.Entry, id string) (string, error) {
	conn, err := grpc.NewClient(c.PipelineAPIURL, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		return "", fmt.Errorf("error connecting to repo proxy API: %v", err)
	}

	defer conn.Close()

	client := pplproto.NewPipelineServiceClient(conn)
	res, err := client.Describe(context.TODO(), &pplproto.DescribeRequest{
		PplId:    id,
		Detailed: false,
	})

	if err != nil {
		return "", fmt.Errorf("error describing pipeline: %v", err)
	}

	logger.Infof("Pipeline result: %s", res.Pipeline.Result.String())

	if res.Pipeline.Result == pplproto.Pipeline_PASSED {
		return models.StageExecutionResultPassed, nil
	}

	return models.StageExecutionResultFailed, nil
}

func (c *PipelineDoneConsumer) createStageCompletionEvent(logger *log.Entry, execution *models.StageExecution, result string) error {
	completionEvent := events.StageCompletionEvent{
		Stage: events.Stage{
			ID: execution.StageID.String(),
		},
		Result: result,
	}

	raw, err := json.Marshal(&completionEvent)
	if err != nil {
		return fmt.Errorf("error marshaling event: %v", err)
	}

	event, err := models.CreateEvent(execution.StageID, models.SourceTypeStage, raw)
	if err != nil {
		return fmt.Errorf("error creating event: %v", err)
	}

	logger.Infof("Created event %s", event.ID)

	return nil
}
