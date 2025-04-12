package models

import (
	"strings"
	"time"

	uuid "github.com/google/uuid"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/database"
	"gorm.io/gorm/clause"
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

// NOTE: caller must encrypt the key before calling this method.
func CreateEventSource(name string, organizationID uuid.UUID, canvasID uuid.UUID, key []byte) (*EventSource, error) {
	now := time.Now()

	eventSource := EventSource{
		Name:           name,
		OrganizationID: organizationID,
		CanvasID:       canvasID,
		CreatedAt:      &now,
		UpdatedAt:      &now,
		Key:            key,
	}

	err := database.Conn().
		Clauses(clause.Returning{}).
		Create(&eventSource).
		Error

	if err == nil {
		return &eventSource, nil
	}

	if strings.Contains(err.Error(), "duplicate key value violates unique constraint") {
		return nil, ErrNameAlreadyUsed
	}

	return nil, err
}

// NOTE: the caller must decrypt the key before using it
func FindEventSourceByID(id uuid.UUID, organizationID uuid.UUID) (*EventSource, error) {
	var eventSource EventSource
	err := database.Conn().
		Where("id = ?", id).
		Where("organization_id = ?", organizationID).
		First(&eventSource).
		Error

	if err != nil {
		return nil, err
	}

	return &eventSource, nil
}
