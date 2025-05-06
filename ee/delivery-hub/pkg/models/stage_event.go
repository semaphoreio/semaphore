package models

import (
	"fmt"
	"strings"
	"time"

	uuid "github.com/google/uuid"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/database"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

const (
	StageEventStatePending   = "pending"
	StageEventStateWaiting   = "waiting"
	StageEventStateProcessed = "processed"

	StageEventStateReasonApproval   = "approval"
	StageEventStateReasonTimeWindow = "time-window"
)

var (
	ErrEventAlreadyApprovedByRequester = fmt.Errorf("event already approved by requester")
)

type StageEvent struct {
	ID          uuid.UUID `gorm:"primary_key;default:uuid_generate_v4()"`
	StageID     uuid.UUID
	EventID     uuid.UUID
	SourceID    uuid.UUID
	SourceName  string
	SourceType  string
	State       string
	StateReason string
	CreatedAt   *time.Time
}

func (e *StageEvent) UpdateState(state, reason string) error {
	return e.UpdateStateInTransaction(database.Conn(), state, reason)
}

func (e *StageEvent) UpdateStateInTransaction(tx *gorm.DB, state, reason string) error {
	return tx.Model(e).
		Clauses(clause.Returning{}).
		Update("state", state).
		Update("state_reason", reason).
		Error
}

func (e *StageEvent) Approve(requesterID uuid.UUID) error {
	now := time.Now()

	approval := StageEventApproval{
		StageEventID: e.ID,
		ApprovedAt:   &now,
		ApprovedBy:   &requesterID,
	}

	err := database.Conn().Create(&approval).Error
	if err != nil {
		if strings.Contains(err.Error(), "duplicate key value violates unique constraint") {
			return ErrEventAlreadyApprovedByRequester
		}

		return err
	}

	return nil
}

func (e *StageEvent) FindApprovals() ([]StageEventApproval, error) {
	var approvals []StageEventApproval
	err := database.Conn().
		Where("stage_event_id = ?", e.ID).
		Find(&approvals).
		Error

	if err != nil {
		return nil, err
	}

	return approvals, nil
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
		SourceName: event.SourceName,
		SourceType: event.SourceType,
		State:      StageEventStatePending,
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
		Where("state = ?", StageEventStatePending).
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
		Where("state = ?", StageEventStatePending).
		Find(&stageIDs).
		Error

	if err != nil {
		return nil, err
	}

	return stageIDs, nil
}
