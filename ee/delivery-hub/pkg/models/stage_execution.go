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

	StageExecutionResultPassed = "passed"
	StageExecutionResultFailed = "failed"
)

type StageExecution struct {
	ID           uuid.UUID `gorm:"primary_key;default:uuid_generate_v4()"`
	StageID      uuid.UUID
	StageEventID uuid.UUID
	State        string
	Result       string
	CreatedAt    *time.Time
	UpdatedAt    *time.Time
	StartedAt    *time.Time
	FinishedAt   *time.Time

	//
	// The ID of the "thing" that is running.
	// For now, this is a Semaphore workflow, but we might want to support other types of executions in the future,
	// so keeping the name generic for now, and also not using uuid.UUID for this column, since we can't guarantee
	// that all IDs will be UUIDs.
	//
	ReferenceID string
}

func (e *StageExecution) Start(referenceID string) error {
	now := time.Now()

	return database.Conn().
		Model(e).
		Update("reference_id", referenceID).
		Update("state", StageExecutionStarted).
		Update("started_at", &now).
		Update("updated_at", &now).
		Error
}

func (e *StageExecution) Finish(result string) error {
	now := time.Now()

	return database.Conn().
		Model(e).
		Clauses(clause.Returning{}).
		Update("result", result).
		Update("state", StageExecutionFinished).
		Update("updated_at", &now).
		Update("finished_at", &now).
		Error
}

func FindExecutionByReference(referenceId string) (*StageExecution, error) {
	var execution StageExecution

	err := database.Conn().
		Where("reference_id = ?", referenceId).
		First(&execution).
		Error

	if err != nil {
		return nil, err
	}

	return &execution, nil
}

func FindExecutionByID(id uuid.UUID) (*StageExecution, error) {
	var execution StageExecution

	err := database.Conn().
		Where("id = ?", id).
		First(&execution).
		Error

	if err != nil {
		return nil, err
	}

	return &execution, nil
}

func FindExecutionInState(stageID uuid.UUID, states []string) (*StageExecution, error) {
	var execution StageExecution

	err := database.Conn().
		Where("stage_id = ?", stageID).
		Where("state IN ?", states).
		First(&execution).
		Error

	if err != nil {
		return nil, err
	}

	return &execution, nil
}

func ListPendingStageExecutions() ([]StageExecution, error) {
	var executions []StageExecution

	err := database.Conn().
		Where("state = ?", StageExecutionPending).
		Find(&executions).
		Error

	if err != nil {
		return nil, err
	}

	return executions, nil
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
		UpdatedAt:    &now,
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
