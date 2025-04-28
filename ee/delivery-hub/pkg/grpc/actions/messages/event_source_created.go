package messages

import (
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/models"
	pb "github.com/semaphoreio/semaphore/delivery-hub/pkg/protos/delivery"
)

type EventSourceCreatedMessage struct {
	message *pb.EventSourceCreated
}

func NewEventSourceCreatedMessage(eventSource *models.EventSource) EventSourceCreatedMessage {
	return EventSourceCreatedMessage{
		message: &pb.EventSourceCreated{
			SourceId: eventSource.ID.String(),
		},
	}
}

func (m EventSourceCreatedMessage) Publish() error {
	return Publish(toJSON(m.message), "created")
}
