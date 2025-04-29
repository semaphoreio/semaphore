package messages

import (
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/models"
	pb "github.com/semaphoreio/semaphore/delivery-hub/pkg/protos/delivery"
	"google.golang.org/protobuf/types/known/timestamppb"
)

const StageCreatedRoutingKey = "stage-created"

type StageCreatedMessage struct {
	message *pb.StageCreated
}

func NewStageCreatedMessage(stage *models.Stage) StageCreatedMessage {
	return StageCreatedMessage{
		message: &pb.StageCreated{
			CanvasId:  stage.CanvasID.String(),
			StageId:   stage.ID.String(),
			Timestamp: timestamppb.Now(),
		},
	}
}

func (m StageCreatedMessage) Publish() error {
	return Publish(DeliveryHubCanvasExchange, StageCreatedRoutingKey, toBytes(m.message))
}
