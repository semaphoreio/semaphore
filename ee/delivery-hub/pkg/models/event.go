package models

import (
	"encoding/json"
	"fmt"
	"strings"
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

func (e *Event) GetNestedField(path string) (any, error) {
	var obj map[string]any
	err := json.Unmarshal(e.Raw, &obj)
	if err != nil {
		return "", err
	}

	return e.getNestedField(obj, strings.Split(path, "."))
}

// TODO: support array traversing or use expr-lang for this too
func (e *Event) getNestedField(obj map[string]any, path []string) (any, error) {
	first := path[0]
	v, ok := obj[first]
	if !ok {
		return nil, fmt.Errorf("key '%s' not found", first)
	}

	//
	// We have reached the end of the recursion, just return the value.
	//
	if len(path) == 1 {
		return v, nil
	}

	//
	// If the current value is not a map, and we still have more path to traverse,
	// this is not a valid path. We should stop and fail here.
	//
	m, ok := v.(map[string]any)
	if !ok {
		return nil, fmt.Errorf("key '%s' is not a map", first)
	}

	//
	// Otherwise, continue traversing.
	//
	return e.getNestedField(m, path[1:])
}

func CreateEvent(sourceID uuid.UUID, sourceType string, raw []byte) (*Event, error) {
	now := time.Now()

	event := Event{
		SourceID:   sourceID,
		SourceType: sourceType,
		State:      EventStatePending,
		ReceivedAt: &now,
		Raw:        datatypes.JSON(raw),
	}

	err := database.Conn().
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
