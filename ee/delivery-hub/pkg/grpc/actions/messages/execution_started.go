package messages

import (
	"fmt"

	"github.com/semaphoreio/semaphore/delivery-hub/pkg/models"
	pb "github.com/semaphoreio/semaphore/delivery-hub/pkg/protos/delivery"
	"google.golang.org/protobuf/types/known/timestamppb"
)

const ExecutionStartedExchange = "DeliveryHub.ExecutionExchange"
const ExecutionStartedRoutingKey = "started"

type ExecutionStartedMessage struct {
	stageId string
	message *pb.StageExecutionStarted
}

func NewExecutionStartedMessage(execution *models.StageExecution) ExecutionStartedMessage {
	return ExecutionStartedMessage{
		stageId: execution.StageID.String(),
		message: &pb.StageExecutionStarted{
			ExecutionId: execution.ID.String(),
			StageId:     execution.StageID.String(),
			EventId:     execution.StageEventID.String(),
			Timestamp:   timestamppb.Now(),
		},
	}
}

func (m ExecutionStartedMessage) Publish() error {
	return Publish(ExecutionStartedExchange, m.BuildRoutingKey(), toJSON(m.message))
}

func (m ExecutionStartedMessage) BuildRoutingKey() string {
	return fmt.Sprintf("%s.%s", ExecutionStartedRoutingKey, m.stageId)
}
