package messages

import (
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/models"
	pb "github.com/semaphoreio/semaphore/delivery-hub/pkg/protos/delivery"
)

type StageCreatedMessage struct {
	message *pb.StageCreated
}

func NewStageCreatedMessage(stage *models.Stage) StageCreatedMessage {
	return StageCreatedMessage{
		message: &pb.StageCreated{
			StageId: stage.ID.String(),
		},
	}
}

func (m StageCreatedMessage) Publish() error {
	return Publish(toJSON(m.message), "created")
}
