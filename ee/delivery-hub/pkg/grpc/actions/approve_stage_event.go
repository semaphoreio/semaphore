package actions

import (
	"context"
	"errors"

	"github.com/semaphoreio/semaphore/delivery-hub/pkg/grpc/actions/messages"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/logging"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/models"
	pb "github.com/semaphoreio/semaphore/delivery-hub/pkg/protos/delivery"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"gorm.io/gorm"
)

func ApproveStageEvent(ctx context.Context, req *pb.ApproveStageEventRequest) (*pb.ApproveStageEventResponse, error) {
	err := ValidateUUIDs(req.OrganizationId, req.CanvasId, req.StageId, req.EventId, req.RequesterId)
	if err != nil {
		return nil, err
	}

	canvas, err := models.FindCanvasByID(req.CanvasId, req.OrganizationId)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, status.Errorf(codes.InvalidArgument, "canvas not found")
		}

		return nil, err
	}

	stage, err := canvas.FindStageByID(req.StageId)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, status.Errorf(codes.InvalidArgument, "stage not found")
		}

		return nil, err
	}

	event, err := models.FindStageEventByID(req.EventId, req.StageId)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, status.Errorf(codes.InvalidArgument, "event not found")
		}

		return nil, err
	}

	err = event.Approve(req.RequesterId)
	if err != nil {
		return nil, err
	}

	err = messages.NewStageEventApprovedMessage(event).Publish()
	if err != nil {
		logging.ForStage(stage).Errorf("failed to publish event approved message: %v", err)
	}

	logging.ForStage(stage).Infof("event %s approved", event.ID)

	return &pb.ApproveStageEventResponse{
		Event: serializeStageEvent(*event),
	}, nil
}
