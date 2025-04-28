package messages

import (
	"fmt"

	"github.com/semaphoreio/semaphore/delivery-hub/pkg/models"
	pb "github.com/semaphoreio/semaphore/delivery-hub/pkg/protos/delivery"
	"google.golang.org/protobuf/types/known/timestamppb"
)

type EventSourceCreatedMessage struct {
	message  *pb.EventSourceCreated
	canvasId string
}

const EventSourceCreatedExchange = "DeliveryHub.EventSourceExchange"
const EventSourceCreatedRoutingKey = "created"

func NewEventSourceCreatedMessage(eventSource *models.EventSource) EventSourceCreatedMessage {
	return EventSourceCreatedMessage{
		canvasId: eventSource.CanvasID.String(),
		message: &pb.EventSourceCreated{
			SourceId:  eventSource.ID.String(),
			Timestamp: timestamppb.Now(),
		},
	}
}

func (m EventSourceCreatedMessage) Publish() error {
	return Publish(EventSourceCreatedExchange, m.BuildRoutingKey(), toJSON(m.message))
}

func (m EventSourceCreatedMessage) BuildRoutingKey() string {
	return fmt.Sprintf("%s.%s", EventSourceCreatedRoutingKey, m.canvasId)
}
