package workers

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/renderedtext/go-tackle"
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

	result, err := c.findPipelineResult(ID)
	if err != nil {
		return fmt.Errorf("error finding pipeline result for %s: %v", ID, err)
	}

	execution, err := models.FindExecutionByReference(ID)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			log.Infof("No execution for %s - ignoring", ID)
			return nil
		}
	}

	if err := execution.Finish(result); err != nil {
		return fmt.Errorf("error finishing execution %s: %v", execution.ID, err)
	}

	return nil
}

func (c *PipelineDoneConsumer) findPipelineResult(id string) (string, error) {
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

	if res.Pipeline.Result == pplproto.Pipeline_PASSED {
		return models.StageExecutionResultPassed, nil
	}

	return models.StageExecutionResultFailed, nil
}
