package models

import (
	"time"

	uuid "github.com/google/uuid"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/database"
)

type EventSource struct {
	ID             uuid.UUID `gorm:"primary_key;default:uuid_generate_v4()"`
	OrganizationID uuid.UUID
	CanvasID       uuid.UUID
	Name           string
	Key            []byte
	CreatedAt      *time.Time
	UpdatedAt      *time.Time
}

// NOTE: the caller must decrypt the key before using it
func FindEventSourceByID(id, organizationID, canvasID *uuid.UUID) (*EventSource, error) {
	var eventSource EventSource
	query := database.Conn().
		Where("id = ?", id).
		Where("organization_id = ?", organizationID)

	if canvasID != nil {
		query = query.Where("canvas_id = ?", canvasID)
	}

	err := query.First(&eventSource).Error
	if err != nil {
		return nil, err
	}

	return &eventSource, nil
}

func FindEventSourceByName(orgID, canvasID uuid.UUID, name string) (*EventSource, error) {
	var eventSource EventSource
	err := database.Conn().
		Where("organization_id = ?", orgID).
		Where("canvas_id = ?", canvasID).
		Where("name = ?", name).
		First(&eventSource).
		Error

	if err != nil {
		return nil, err
	}

	return &eventSource, nil
}

func ListEventSourcesByCanvasID(orgID, canvasID uuid.UUID) ([]EventSource, error) {
	var sources []EventSource
	err := database.Conn().
		Where("canvas_id = ?", canvasID).
		Where("organization_id = ?", orgID).
		Find(&sources).
		Error

	if err != nil {
		return nil, err
	}

	return sources, nil
}
