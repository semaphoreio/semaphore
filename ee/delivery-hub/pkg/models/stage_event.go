package models

import (
	"time"

	uuid "github.com/google/uuid"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/database"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

const (
	StageEventPending = "pending"

	// TODO: might be easier to have a waiting state,
	// and a separate WaitReason field, but we can revisit that later.
	StageEventWaitingForApproval   = "waiting-for-approval"
	StageEventWaitingForTimeWindow = "waiting-for-time-window"

	StageEventProcessed = "processed"
)

type StageEvent struct {
	ID         uuid.UUID `gorm:"primary_key;default:uuid_generate_v4()"`
	StageID    uuid.UUID
	EventID    uuid.UUID
	SourceID   uuid.UUID
	SourceType string
	State      string
	CreatedAt  *time.Time
	ApprovedAt *time.Time
	ApprovedBy *uuid.UUID
}

func (e *StageEvent) UpdateState(state string) error {
	return e.UpdateStateInTransaction(database.Conn(), state)
}

func (e *StageEvent) UpdateStateInTransaction(tx *gorm.DB, state string) error {
	return tx.Model(e).Update("state", state).Error
}

func (e *StageEvent) Approve(requesterID string) error {
	now := time.Now()

	return database.Conn().
		Model(e).
		Update("state", StageEventPending).
		Update("approved_at", &now).
		Update("approved_by", requesterID).
		Error
}

func FindStageEventByID(id, stageID string) (*StageEvent, error) {
	var event StageEvent

	err := database.Conn().
		Where("id = ?", id).
		Where("stage_id = ?", stageID).
		First(&event).
		Error

	if err != nil {
		return nil, err
	}

	return &event, nil
}

func CreateStageEvent(stageID uuid.UUID, event *Event) (*StageEvent, error) {
	return CreateStageEventInTransaction(database.Conn(), stageID, event)
}

func CreateStageEventInTransaction(tx *gorm.DB, stageID uuid.UUID, event *Event) (*StageEvent, error) {
	now := time.Now()
	stageEvent := StageEvent{
		StageID:    stageID,
		EventID:    event.ID,
		SourceID:   event.SourceID,
		SourceType: event.SourceType,
		State:      StageEventPending,
		CreatedAt:  &now,
	}

	err := tx.Create(&stageEvent).
		Clauses(clause.Returning{}).
		Error

	if err != nil {
		return nil, err
	}

	return &stageEvent, nil
}

func FindOldestPendingStageEvent(stageID uuid.UUID) (*StageEvent, error) {
	var event StageEvent

	err := database.Conn().
		Where("state = ?", StageEventPending).
		Where("stage_id = ?", stageID).
		Order("created_at ASC").
		First(&event).
		Error

	if err != nil {
		return nil, err
	}

	return &event, nil
}

func FindStagesWithPendingEvents() ([]uuid.UUID, error) {
	var stageIDs []uuid.UUID

	err := database.Conn().
		Table("stage_events").
		Distinct("stage_id").
		Where("state = ?", StageEventPending).
		Find(&stageIDs).
		Error

	if err != nil {
		return nil, err
	}

	return stageIDs, nil
}
