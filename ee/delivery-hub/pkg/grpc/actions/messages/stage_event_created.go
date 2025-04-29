package messages

import (
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/models"
	pb "github.com/semaphoreio/semaphore/delivery-hub/pkg/protos/delivery"
	"google.golang.org/protobuf/types/known/timestamppb"
)

const StageEventCreatedExchange = "DeliveryHub.CanvasExchange"
const StageEventCreatedRoutingKey = "stage-event-created"

type StageEventCreatedMessage struct {
	message *pb.StageEventCreated
}

func NewStageEventCreatedMessage(eventSource *models.StageEvent) StageEventCreatedMessage {
	return StageEventCreatedMessage{
		message: &pb.StageEventCreated{
			EventId:   eventSource.ID.String(),
			Timestamp: timestamppb.Now(),
		},
	}
}

func (m StageEventCreatedMessage) Publish() error {
	return Publish(StageEventCreatedExchange, StageEventCreatedRoutingKey, toJSON(m.message))
}
