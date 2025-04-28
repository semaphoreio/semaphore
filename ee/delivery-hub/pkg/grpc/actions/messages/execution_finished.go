package messages

import (
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/models"
	pb "github.com/semaphoreio/semaphore/delivery-hub/pkg/protos/delivery"
	"google.golang.org/protobuf/types/known/timestamppb"
)

const ExecutionFinishedExchange = "DeliveryHub.ExecutionExchange"
const ExecutionFinishedRoutingKey = "finished"

type ExecutionFinishedMessage struct {
	message *pb.StageExecutionFinished
}

func NewExecutionFinishedMessage(execution *models.StageExecution) ExecutionFinishedMessage {
	return ExecutionFinishedMessage{
		message: &pb.StageExecutionFinished{
			ExecutionId: execution.ID.String(),
			StageId:     execution.StageID.String(),
			EventId:     execution.StageEventID.String(),
			Timestamp:   timestamppb.Now(),
		},
	}
}

func (m ExecutionFinishedMessage) Publish() error {
	return Publish(ExecutionFinishedExchange, ExecutionFinishedRoutingKey, toJSON(m.message))
}
