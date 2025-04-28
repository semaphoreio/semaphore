package messages

import (
	"fmt"

	"github.com/semaphoreio/semaphore/delivery-hub/pkg/models"
	pb "github.com/semaphoreio/semaphore/delivery-hub/pkg/protos/delivery"
	"google.golang.org/protobuf/types/known/timestamppb"
)

const StageEventCreatedExchange = "DeliveryHub.StageEventExchange"
const StageEventCreatedRoutingKey = "created"

type StageEventCreatedMessage struct {
	message *pb.StageEventCreated
	stageId string
}

func NewStageEventCreatedMessage(eventSource *models.StageEvent) StageEventCreatedMessage {
	return StageEventCreatedMessage{
		stageId: eventSource.StageID.String(),
		message: &pb.StageEventCreated{
			EventId:   eventSource.ID.String(),
			Timestamp: timestamppb.Now(),
		},
	}
}

func (m StageEventCreatedMessage) Publish() error {
	return Publish(StageEventCreatedExchange, m.BuildRoutingKey(), toJSON(m.message))
}

func (m StageEventCreatedMessage) BuildRoutingKey() string {
	return fmt.Sprintf("%s.%s", StageEventCreatedRoutingKey, m.stageId)
}
