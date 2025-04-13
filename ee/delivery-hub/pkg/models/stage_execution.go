package models

import (
	"time"

	uuid "github.com/google/uuid"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/database"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

const (
	StageExecutionPending  = "pending"
	StageExecutionStarted  = "started"
	StageExecutionFinished = "finished"
)

type StageExecution struct {
	ID           uuid.UUID `gorm:"primary_key;default:uuid_generate_v4()"`
	StageID      uuid.UUID
	StageEventID uuid.UUID
	State        string
	CreatedAt    *time.Time
}

func FindExecutionInState(stageID uuid.UUID, states []string) (*StageExecution, error) {
	var execution StageExecution

	err := database.Conn().
		Where("stage_id = ? AND state IN ?", stageID, states).
		First(&execution).
		Error

	if err != nil {
		return nil, err
	}

	return &execution, nil
}

func CreateStageExecution(stageID, stageEventID uuid.UUID) (*StageExecution, error) {
	return CreateStageExecutionInTransaction(database.Conn(), stageID, stageEventID)
}

func CreateStageExecutionInTransaction(tx *gorm.DB, stageID, stageEventID uuid.UUID) (*StageExecution, error) {
	now := time.Now()
	execution := StageExecution{
		StageID:      stageID,
		StageEventID: stageEventID,
		State:        StageExecutionPending,
		CreatedAt:    &now,
	}

	err := tx.
		Clauses(clause.Returning{}).
		Create(&execution).
		Error

	if err != nil {
		return nil, err
	}

	return &execution, nil
}
