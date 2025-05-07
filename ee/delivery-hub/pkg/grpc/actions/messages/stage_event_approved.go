package messages

import (
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/models"
	pb "github.com/semaphoreio/semaphore/delivery-hub/pkg/protos/delivery"
	"google.golang.org/protobuf/types/known/timestamppb"
)

const StageEventApprovedRoutingKey = "stage-event-approved"

type StageEventApprovedMessage struct {
	message *pb.StageEventApproved
}

func NewStageEventApprovedMessage(canvasId string, eventSource *models.StageEvent) StageEventApprovedMessage {
	return StageEventApprovedMessage{
		message: &pb.StageEventApproved{
			CanvasId:  canvasId,
			StageId:   eventSource.StageID.String(),
			EventId:   eventSource.ID.String(),
			Timestamp: timestamppb.Now(),
		},
	}
}

func (m StageEventApprovedMessage) Publish() error {
	return Publish(DeliveryHubCanvasExchange, StageEventApprovedRoutingKey, toBytes(m.message))
}
