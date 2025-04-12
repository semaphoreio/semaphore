package models

import (
	"time"

	uuid "github.com/google/uuid"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/database"
	"gorm.io/gorm"
)

const (
	StageEventPending = "pending"
)

type StageEvent struct {
	ID        uuid.UUID `gorm:"primary_key;default:uuid_generate_v4()"`
	StageID   uuid.UUID
	SourceID  uuid.UUID
	State     string
	CreatedAt *time.Time
}

func CreateStageEvent(stageID, sourceID uuid.UUID) error {
	return CreateStageEventInTransaction(database.Conn(), stageID, sourceID)
}

func CreateStageEventInTransaction(tx *gorm.DB, stageID, sourceID uuid.UUID) error {
	now := time.Now()
	event := StageEvent{
		StageID:   stageID,
		SourceID:  sourceID,
		State:     StageEventPending,
		CreatedAt: &now,
	}

	return tx.Create(&event).Error
}

func ListStageEvents(stageID uuid.UUID) ([]StageEvent, error) {
	var events []StageEvent
	return events, database.Conn().Where("stage_id = ?", stageID).Find(&events).Error
}
