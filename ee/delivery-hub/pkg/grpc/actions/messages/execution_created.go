package messages

import (
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/models"
	pb "github.com/semaphoreio/semaphore/delivery-hub/pkg/protos/delivery"
	"google.golang.org/protobuf/types/known/timestamppb"
)

const ExecutionCreatedRoutingKey = "execution-created"

type ExecutionCreatedMessage struct {
	message *pb.StageExecutionCreated
}

func NewExecutionCreatedMessage(canvasId string, execution *models.StageExecution) ExecutionCreatedMessage {
	return ExecutionCreatedMessage{
		message: &pb.StageExecutionCreated{
			CanvasId:    canvasId,
			ExecutionId: execution.ID.String(),
			StageId:     execution.StageID.String(),
			EventId:     execution.StageEventID.String(),
			Timestamp:   timestamppb.Now(),
		},
	}
}

func (m ExecutionCreatedMessage) Publish() error {
	return Publish(DeliveryHubCanvasExchange, ExecutionCreatedRoutingKey, toBytes(m.message))
}
