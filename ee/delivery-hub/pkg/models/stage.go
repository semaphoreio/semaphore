package models

import (
	"time"

	uuid "github.com/google/uuid"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/database"
)

type Stage struct {
	ID               uuid.UUID `gorm:"type:uuid;primary_key;"`
	OrganizationID   uuid.UUID
	CanvasID         uuid.UUID
	Name             string
	CreatedAt        *time.Time
	ApprovalRequired bool
}

func FindStageByName(orgID, canvasID uuid.UUID, name string) (*Stage, error) {
	var stage Stage

	err := database.Conn().
		Where("organization_id = ?", orgID).
		Where("canvas_id = ?", canvasID).
		Where("name = ?", name).
		First(&stage).
		Error

	if err != nil {
		return nil, err
	}

	return &stage, nil
}

func FindStageByID(id uuid.UUID) (*Stage, error) {
	var stage Stage

	err := database.Conn().
		Where("id = ?", id).
		First(&stage).
		Error

	if err != nil {
		return nil, err
	}

	return &stage, nil
}

func FindStage(id, orgID, canvasID uuid.UUID) (*Stage, error) {
	var stage Stage

	err := database.Conn().
		Where("organization_id = ?", orgID).
		Where("canvas_id = ?", canvasID).
		Where("id = ?", id).
		First(&stage).
		Error

	if err != nil {
		return nil, err
	}

	return &stage, nil
}

func (s *Stage) ListEvents() ([]StageEvent, error) {
	var events []StageEvent
	return events, database.Conn().Where("stage_id = ?", s.ID).Find(&events).Error
}

func ListStagesByIDs(ids []uuid.UUID) ([]Stage, error) {
	var stages []Stage

	err := database.Conn().
		Where("id IN ?", ids).
		Find(&stages).
		Error

	if err != nil {
		return nil, err
	}

	return stages, nil
}

func ListStagesByCanvasID(orgID, canvasID uuid.UUID) ([]Stage, error) {
	var stages []Stage

	err := database.Conn().
		Where("organization_id = ?", orgID).
		Where("canvas_id = ?", canvasID).
		Order("name ASC").
		Find(&stages).
		Error

	if err != nil {
		return nil, err
	}

	return stages, nil
}
