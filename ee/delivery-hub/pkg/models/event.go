package models

import (
	"context"
	"encoding/json"
	"fmt"
	"reflect"
	"time"

	"github.com/expr-lang/expr"
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

func (e *Event) EvaluateBoolExpression(expression string) (bool, error) {
	//
	// We don't want the expression to run for more than 5 seconds.
	//
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	//
	// Build our variable map.
	//
	variables := map[string]interface{}{
		"ctx": ctx,
	}

	data, err := e.GetData()
	if err != nil {
		return false, err
	}

	for key, value := range data {
		variables[key] = value
	}

	//
	// Compile and run our expression.
	//
	program, err := expr.Compile(expression,
		expr.Env(variables),
		expr.AsBool(),
		expr.WithContext("ctx"),
		expr.Timezone(time.UTC.String()),
	)

	if err != nil {
		return false, fmt.Errorf("error compiling expression: %v", err)
	}

	output, err := expr.Run(program, variables)
	if err != nil {
		return false, fmt.Errorf("error running expression: %v", err)
	}

	//
	// Output of the expression must be a boolean.
	//
	v, ok := output.(bool)
	if !ok {
		return false, fmt.Errorf("expression does not return a boolean")
	}

	return v, nil
}

func (e *Event) EvaluateStringExpression(expression string) (string, error) {
	//
	// We don't want the expression to run for more than 5 seconds.
	//
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	//
	// Build our variable map.
	//
	variables := map[string]interface{}{
		"ctx": ctx,
	}

	data, err := e.GetData()
	if err != nil {
		return "", err
	}

	for key, value := range data {
		variables[key] = value
	}

	//
	// Compile and run our expression.
	//
	program, err := expr.Compile(expression,
		expr.Env(variables),
		expr.AsKind(reflect.String),
		expr.WithContext("ctx"),
		expr.Timezone(time.UTC.String()),
	)

	if err != nil {
		return "", fmt.Errorf("error compiling expression: %v", err)
	}

	output, err := expr.Run(program, variables)
	if err != nil {
		return "", fmt.Errorf("error running expression: %v", err)
	}

	//
	// Output of the expression must be a string.
	//
	v, ok := output.(string)
	if !ok {
		return "", fmt.Errorf("expression does not return a string")
	}

	return v, nil
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
