package messages

import (
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/models"
	pb "github.com/semaphoreio/semaphore/delivery-hub/pkg/protos/delivery"
	"google.golang.org/protobuf/types/known/timestamppb"
)

const StageUpdatedRoutingKey = "stage-updated"

type StageUpdatedMessage struct {
	message *pb.StageUpdated
}

func NewStageUpdatedMessage(stage *models.Stage) StageUpdatedMessage {
	return StageUpdatedMessage{
		message: &pb.StageUpdated{
			CanvasId:  stage.CanvasID.String(),
			StageId:   stage.ID.String(),
			Timestamp: timestamppb.Now(),
		},
	}
}

func (m StageUpdatedMessage) Publish() error {
	return Publish(DeliveryHubCanvasExchange, StageUpdatedRoutingKey, toBytes(m.message))
}
