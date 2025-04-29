package messages

import (
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/models"
	pb "github.com/semaphoreio/semaphore/delivery-hub/pkg/protos/delivery"
	"google.golang.org/protobuf/types/known/timestamppb"
)

type EventSourceCreatedMessage struct {
	message *pb.EventSourceCreated
}

const EventSourceCreatedExchange = "DeliveryHub.CanvasExchange"
const EventSourceCreatedRoutingKey = "event-source-created"

func NewEventSourceCreatedMessage(eventSource *models.EventSource) EventSourceCreatedMessage {
	return EventSourceCreatedMessage{
		message: &pb.EventSourceCreated{
			CanvasId:  eventSource.CanvasID.String(),
			SourceId:  eventSource.ID.String(),
			Timestamp: timestamppb.Now(),
		},
	}
}

func (m EventSourceCreatedMessage) Publish() error {
	return Publish(EventSourceCreatedExchange, EventSourceCreatedRoutingKey, toJSON(m.message))
}
