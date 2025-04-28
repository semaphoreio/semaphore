package messages

import (
	"fmt"

	"github.com/semaphoreio/semaphore/delivery-hub/pkg/models"
	pb "github.com/semaphoreio/semaphore/delivery-hub/pkg/protos/delivery"
	"google.golang.org/protobuf/types/known/timestamppb"
)

const ExecutionFinishedExchange = "DeliveryHub.ExecutionExchange"
const ExecutionFinishedRoutingKey = "finished"

type ExecutionFinishedMessage struct {
	stageId string
	message *pb.StageExecutionFinished
}

func NewExecutionFinishedMessage(execution *models.StageExecution) ExecutionFinishedMessage {
	return ExecutionFinishedMessage{
		stageId: execution.StageID.String(),
		message: &pb.StageExecutionFinished{
			ExecutionId: execution.ID.String(),
			StageId:     execution.StageID.String(),
			EventId:     execution.StageEventID.String(),
			Timestamp:   timestamppb.Now(),
		},
	}
}

func (m ExecutionFinishedMessage) Publish() error {
	return Publish(ExecutionFinishedExchange, m.BuildRoutingKey(), toJSON(m.message))
}

func (m ExecutionFinishedMessage) BuildRoutingKey() string {
	return fmt.Sprintf("%s.%s", ExecutionFinishedRoutingKey, m.stageId)
}
