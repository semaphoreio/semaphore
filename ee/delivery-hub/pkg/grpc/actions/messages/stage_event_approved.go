package messages

import (
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/models"
	pb "github.com/semaphoreio/semaphore/delivery-hub/pkg/protos/delivery"
	"google.golang.org/protobuf/types/known/timestamppb"
)

const StageEventApprovedExchange = "DeliveryHub.StageEventExchange"
const StageEventApprovedRoutingKey = "approved"

type StageEventApprovedMessage struct {
	message *pb.StageEventApproved
}

func NewStageEventApprovedMessage(eventSource *models.StageEvent) StageEventApprovedMessage {
	return StageEventApprovedMessage{
		message: &pb.StageEventApproved{
			EventId:   eventSource.ID.String(),
			Timestamp: timestamppb.Now(),
		},
	}
}

func (m StageEventApprovedMessage) Publish() error {
	return Publish(StageEventApprovedExchange, StageEventApprovedRoutingKey, toJSON(m.message))
}
