package messages

import (
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/models"
	pb "github.com/semaphoreio/semaphore/delivery-hub/pkg/protos/delivery"
	"google.golang.org/protobuf/types/known/timestamppb"
)

const ExecutionStartedExchange = "DeliveryHub.CanvasExchange"
const ExecutionStartedRoutingKey = "execution-started"

type ExecutionStartedMessage struct {
	message *pb.StageExecutionStarted
}

func NewExecutionStartedMessage(canvasId string, execution *models.StageExecution) ExecutionStartedMessage {
	return ExecutionStartedMessage{
		message: &pb.StageExecutionStarted{
			CanvasId:    canvasId,
			ExecutionId: execution.ID.String(),
			StageId:     execution.StageID.String(),
			EventId:     execution.StageEventID.String(),
			Timestamp:   timestamppb.Now(),
		},
	}
}

func (m ExecutionStartedMessage) Publish() error {
	return Publish(ExecutionStartedExchange, ExecutionStartedRoutingKey, toJSON(m.message))
}
