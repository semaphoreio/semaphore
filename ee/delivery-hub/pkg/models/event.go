package models

import (
	"encoding/json"
	"fmt"
	"time"

	uuid "github.com/google/uuid"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/database"
	"gorm.io/datatypes"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

const (
	EventStatePending   = "pending"
	EventStateDiscarded = "discarded"
	EventStateProcessed = "processed"

	SourceTypeEventSource = "event-source"
	SourceTypeStage       = "stage"
)

type Event struct {
	ID         uuid.UUID `gorm:"primary_key;default:uuid_generate_v4()"`
	SourceID   uuid.UUID
	SourceName string
	SourceType string
	State      string
	ReceivedAt *time.Time
	Raw        datatypes.JSON
}

func (e *Event) Discard() error {
	return database.Conn().Model(e).
		Update("state", EventStateDiscarded).
		Error
}

func (e *Event) MarkAsProcessed() error {
	return e.MarkAsProcessedInTransaction(database.Conn())
}

func (e *Event) MarkAsProcessedInTransaction(tx *gorm.DB) error {
	return tx.Model(e).
		Update("state", EventStateProcessed).
		Error
}

func (e *Event) GetData() (map[string]any, error) {
	var obj map[string]any
	err := json.Unmarshal(e.Raw, &obj)
	if err != nil {
		return nil, err
	}

	return obj, nil
}

func CreateEvent(sourceID uuid.UUID, sourceName, sourceType string, raw []byte) (*Event, error) {
	return CreateEventInTransaction(database.Conn(), sourceID, sourceName, sourceType, raw)
}

func CreateEventInTransaction(tx *gorm.DB, sourceID uuid.UUID, sourceName, sourceType string, raw []byte) (*Event, error) {
	now := time.Now()

	event := Event{
		SourceID:   sourceID,
		SourceName: sourceName,
		SourceType: sourceType,
		State:      EventStatePending,
		ReceivedAt: &now,
		Raw:        datatypes.JSON(raw),
	}

	err := tx.
		Clauses(clause.Returning{}).
		Create(&event).
		Error

	if err != nil {
		return nil, err
	}

	return &event, nil
}

func ListEventsBySourceID(sourceID uuid.UUID) ([]Event, error) {
	var events []Event
	return events, database.Conn().Where("source_id = ?", sourceID).Find(&events).Error
}

func ListPendingEvents() ([]Event, error) {
	var events []Event
	return events, database.Conn().Where("state = ?", EventStatePending).Find(&events).Error
}

func FindEventByID(id uuid.UUID) (*Event, error) {
	var event Event
	return &event, database.Conn().Where("id = ?", id).First(&event).Error
}

func FindLastEventBySourceID(sourceID uuid.UUID) (map[string]any, error) {
	var event Event
	err := database.Conn().
		Table("events").
		Select("raw").
		Where("source_id = ?", sourceID).
		Order("received_at DESC").
		First(&event).
		Error

	if err != nil {
		return nil, fmt.Errorf("error finding event: %v", err)
	}

	var m map[string]any
	err = json.Unmarshal(event.Raw, &m)
	if err != nil {
		return nil, fmt.Errorf("error unmarshaling data: %v", err)
	}

	return m, nil
}
