package models

import (
	"time"

	uuid "github.com/google/uuid"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/database"
	"gorm.io/datatypes"
)

var EventStatePending = "pending"
var EventStateProcessed = "processed"

type Event struct {
	ID         uuid.UUID `gorm:"primary_key;default:uuid_generate_v4()"`
	SourceID   uuid.UUID
	State      string
	ReceivedAt *time.Time
	Raw        datatypes.JSON
}

func CreateEvent(sourceID uuid.UUID, raw []byte) error {
	now := time.Now()

	event := Event{
		SourceID:   sourceID,
		State:      EventStatePending,
		ReceivedAt: &now,
		Raw:        datatypes.JSON(raw),
	}

	return database.Conn().Create(&event).Error
}

func ListEventsBySourceID(sourceID uuid.UUID) ([]Event, error) {
	var events []Event
	return events, database.Conn().Where("source_id = ?", sourceID).Find(&events).Error
}
