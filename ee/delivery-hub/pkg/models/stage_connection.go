package models

import (
	uuid "github.com/google/uuid"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/database"
)

type StageConnection struct {
	ID         uuid.UUID `gorm:"type:uuid;default:uuid_generate_v4()"`
	StageID    uuid.UUID
	SourceID   uuid.UUID
	SourceType string
}

func ListConnectionsForSource(sourceID uuid.UUID, connectionType string) ([]StageConnection, error) {
	var connections []StageConnection
	err := database.Conn().
		Where("source_id = ?", sourceID).
		Where("source_type = ?", connectionType).
		Find(&connections).
		Error

	if err != nil {
		return nil, err
	}

	return connections, nil
}

func ListConnectionsForStage(stageID uuid.UUID) ([]StageConnection, error) {
	var connections []StageConnection
	err := database.Conn().
		Where("stage_id = ?", stageID).
		Find(&connections).
		Error

	if err != nil {
		return nil, err
	}

	return connections, nil
}
