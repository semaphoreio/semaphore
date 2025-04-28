package messages

import (
	"fmt"

	"github.com/semaphoreio/semaphore/delivery-hub/pkg/models"
	pb "github.com/semaphoreio/semaphore/delivery-hub/pkg/protos/delivery"
	"google.golang.org/protobuf/types/known/timestamppb"
)

const ExecutionCreatedExchange = "DeliveryHub.ExecutionExchange"
const ExecutionCreatedRoutingKey = "created"

type ExecutionCreatedMessage struct {
	stageId string
	message *pb.StageExecutionCreated
}

func NewExecutionCreatedMessage(execution *models.StageExecution) ExecutionCreatedMessage {
	return ExecutionCreatedMessage{
		stageId: execution.StageID.String(),
		message: &pb.StageExecutionCreated{
			ExecutionId: execution.ID.String(),
			StageId:     execution.StageID.String(),
			EventId:     execution.StageEventID.String(),
			Timestamp:   timestamppb.Now(),
		},
	}
}

func (m ExecutionCreatedMessage) Publish() error {
	return Publish(ExecutionCreatedExchange, m.BuildRoutingKey(), toJSON(m.message))
}

func (m ExecutionCreatedMessage) BuildRoutingKey() string {
	return fmt.Sprintf("%s.%s", ExecutionCreatedRoutingKey, m.stageId)
}
