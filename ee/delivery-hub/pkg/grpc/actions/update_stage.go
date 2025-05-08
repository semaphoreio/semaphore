package actions

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/database"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/grpc/actions/messages"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/logging"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/models"
	pb "github.com/semaphoreio/semaphore/delivery-hub/pkg/protos/delivery"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"gorm.io/gorm"
)

func UpdateStage(ctx context.Context, req *pb.UpdateStageRequest) (*pb.UpdateStageResponse, error) {
	err := ValidateUUIDs(req.Id, req.RequesterId)

	if err != nil {
		return nil, err
	}

	stageID, _ := uuid.Parse(req.Id)
	requesterID, _ := uuid.Parse(req.RequesterId)

	stage, err := models.FindStageByID(stageID)
	if err != nil {
		return nil, status.Errorf(codes.NotFound, "stage not found")
	}

	canvas, err := models.FindCanvasByID(stage.CanvasID.String(), stage.OrganizationID.String())
	if err != nil {
		return nil, status.Errorf(codes.Internal, "canvas not found")
	}

	connections, err := validateConnections(canvas, req.Connections)
	if err != nil {
		return nil, status.Errorf(codes.InvalidArgument, "invalid connections: %v", err)
	}

	err = updateStageConnections(stageID, connections, requesterID)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "failed to update stage connections")
	}

	stages, err := canvas.ListStages()
	if err != nil {
		return nil, status.Errorf(codes.Internal, "failed to list stages")
	}

	sources, err := canvas.ListEventSources()
	if err != nil {
		return nil, status.Errorf(codes.Internal, "failed to list event sources")
	}

	updatedConnections, err := models.ListConnectionsForStage(stageID)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "failed to list connections")
	}

	serializedConnections, err := serializeConnections(stages, sources, updatedConnections)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "failed to serialize connections")
	}

	updatedStage, err := models.FindStageByID(stageID)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "failed to get updated stage")
	}

	serializedStage, err := serializeStage(*updatedStage, serializedConnections)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "failed to serialize stage")
	}

	err = messages.NewStageUpdatedMessage(updatedStage).Publish()
	if err != nil {
		logging.ForStage(updatedStage).Errorf("failed to publish stage updated message: %v", err)
	}

	return &pb.UpdateStageResponse{
		Stage: serializedStage,
	}, nil
}

// updateStageConnections updates the connections for a stage
func updateStageConnections(stageID uuid.UUID, newConnections []models.StageConnection, requesterID uuid.UUID) error {
	return database.Conn().Transaction(func(tx *gorm.DB) error {
		if err := tx.Where("stage_id = ?", stageID).Delete(&models.StageConnection{}).Error; err != nil {
			return fmt.Errorf("failed to delete existing connections: %v", err)
		}

		for _, connection := range newConnections {
			connection.StageID = stageID
			if err := tx.Create(&connection).Error; err != nil {
				return fmt.Errorf("failed to create connection: %v", err)
			}
		}

		now := time.Now()
		if err := tx.Model(&models.Stage{}).Where("id = ?", stageID).
			Updates(map[string]interface{}{
				"updated_at": now,
				"updated_by": requesterID,
			}).Error; err != nil {
			return fmt.Errorf("failed to update stage timestamp: %v", err)
		}

		return nil
	})
}
