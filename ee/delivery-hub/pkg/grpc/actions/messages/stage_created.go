package messages

import (
	"fmt"

	"github.com/semaphoreio/semaphore/delivery-hub/pkg/models"
	pb "github.com/semaphoreio/semaphore/delivery-hub/pkg/protos/delivery"
	"google.golang.org/protobuf/types/known/timestamppb"
)

const StageCreatedExchange = "DeliveryHub.StageExchange"
const StageCreatedRoutingKey = "created"

type StageCreatedMessage struct {
	canvasId string
	message  *pb.StageCreated
}

func NewStageCreatedMessage(stage *models.Stage) StageCreatedMessage {
	return StageCreatedMessage{
		canvasId: stage.CanvasID.String(),
		message: &pb.StageCreated{
			StageId:   stage.ID.String(),
			Timestamp: timestamppb.Now(),
		},
	}
}

func (m StageCreatedMessage) Publish() error {
	return Publish(StageCreatedExchange, m.BuildRoutingKey(), toJSON(m.message))
}

func (m StageCreatedMessage) BuildRoutingKey() string {
	return fmt.Sprintf("%s.%s", StageCreatedRoutingKey, m.canvasId)
}
