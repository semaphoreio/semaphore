package models

import (
	"time"

	uuid "github.com/google/uuid"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/database"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

const (
	StageEventPending             = "pending"
	StageEventWaitingForApproval  = "waiting-for-approval"
	StageEventWaitingForExecution = "waiting-for-execution"
)

type StageEvent struct {
	ID         uuid.UUID `gorm:"primary_key;default:uuid_generate_v4()"`
	StageID    uuid.UUID
	SourceID   uuid.UUID
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

func (e *StageEvent) Approve(requesterID uuid.UUID) error {
	now := time.Now()

	return database.Conn().
		Model(e).
		Update("state", StageEventPending).
		Update("approved_at", &now).
		Update("approved_by", requesterID).
		Error
}

func FindStageEventByID(id, stageID uuid.UUID) (*StageEvent, error) {
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

func CreateStageEvent(stageID, sourceID uuid.UUID) (*StageEvent, error) {
	return CreateStageEventInTransaction(database.Conn(), stageID, sourceID)
}

func CreateStageEventInTransaction(tx *gorm.DB, stageID, sourceID uuid.UUID) (*StageEvent, error) {
	now := time.Now()
	event := StageEvent{
		StageID:   stageID,
		SourceID:  sourceID,
		State:     StageEventPending,
		CreatedAt: &now,
	}

	err := tx.Create(&event).
		Clauses(clause.Returning{}).
		Error

	if err != nil {
		return nil, err
	}

	return &event, nil
}

type StageEventWithSource struct {
	StageEvent
	SourceID   uuid.UUID
	SourceType string
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
