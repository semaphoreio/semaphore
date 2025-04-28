package messages

import (
	"fmt"

	"github.com/semaphoreio/semaphore/delivery-hub/pkg/models"
	pb "github.com/semaphoreio/semaphore/delivery-hub/pkg/protos/delivery"
	"google.golang.org/protobuf/types/known/timestamppb"
)

const StageEventApprovedExchange = "DeliveryHub.StageEventExchange"
const StageEventApprovedRoutingKey = "approved"

type StageEventApprovedMessage struct {
	message *pb.StageEventApproved
	stageId string
}

func NewStageEventApprovedMessage(eventSource *models.StageEvent) StageEventApprovedMessage {
	return StageEventApprovedMessage{
		stageId: eventSource.StageID.String(),
		message: &pb.StageEventApproved{
			EventId:   eventSource.ID.String(),
			Timestamp: timestamppb.Now(),
		},
	}
}

func (m StageEventApprovedMessage) Publish() error {
	return Publish(StageEventApprovedExchange, m.BuildRoutingKey(), toJSON(m.message))
}

func (m StageEventApprovedMessage) BuildRoutingKey() string {
	return fmt.Sprintf("%s.%s", StageEventApprovedRoutingKey, m.stageId)
}
