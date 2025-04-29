package messages

import (
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/models"
	pb "github.com/semaphoreio/semaphore/delivery-hub/pkg/protos/delivery"
	"google.golang.org/protobuf/types/known/timestamppb"
)

const ExecutionCreatedExchange = "DeliveryHub.CanvasExchange"
const ExecutionCreatedRoutingKey = "execution-created"

type ExecutionCreatedMessage struct {
	message *pb.StageExecutionCreated
}

func NewExecutionCreatedMessage(execution *models.StageExecution) ExecutionCreatedMessage {
	return ExecutionCreatedMessage{
		message: &pb.StageExecutionCreated{
			ExecutionId: execution.ID.String(),
			StageId:     execution.StageID.String(),
			EventId:     execution.StageEventID.String(),
			Timestamp:   timestamppb.Now(),
		},
	}
}

func (m ExecutionCreatedMessage) Publish() error {
	return Publish(ExecutionCreatedExchange, ExecutionCreatedRoutingKey, toJSON(m.message))
}
