package models

import (
	"time"

	uuid "github.com/google/uuid"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/database"
	"gorm.io/datatypes"
)

const (
	RunTemplateTypeSemaphore = "semaphore"
)

type Stage struct {
	ID               uuid.UUID `gorm:"type:uuid;primary_key;"`
	OrganizationID   uuid.UUID
	CanvasID         uuid.UUID
	Name             string
	CreatedAt        *time.Time
	CreatedBy        uuid.UUID
	ApprovalRequired bool

	RunTemplate datatypes.JSONType[RunTemplate]
}

type RunTemplate struct {
	Type string `json:"type"`

	//
	// Triggers a workflow on an existing Semaphore project/task.
	//
	Semaphore *SemaphoreRunTemplate `json:"semaphore_workflow,omitempty"`
}

type SemaphoreRunTemplate struct {
	ProjectID    string            `json:"project_id"`
	Branch       string            `json:"branch"`
	PipelineFile string            `json:"pipeline_file"`
	Parameters   map[string]string `json:"parameters"`
	TaskID       string            `json:"task_id"`
}

func FindStageByIDOnly(id uuid.UUID) (*Stage, error) {
	var stage Stage

	err := database.Conn().
		Where("id = ?", id).
		First(&stage).
		Error

	if err != nil {
		return nil, err
	}

	return &stage, nil
}

func FindStage(id, orgID, canvasID uuid.UUID) (*Stage, error) {
	var stage Stage

	err := database.Conn().
		Where("organization_id = ?", orgID).
		Where("canvas_id = ?", canvasID).
		Where("id = ?", id).
		First(&stage).
		Error

	if err != nil {
		return nil, err
	}

	return &stage, nil
}

func (s *Stage) ListPendingEvents() ([]StageEvent, error) {
	return s.ListEvents([]string{StageEventPending})
}

func (s *Stage) ListEvents(states []string) ([]StageEvent, error) {
	var events []StageEvent
	err := database.Conn().
		Where("stage_id = ?", s.ID).
		Where("state IN ?", states).
		Find(&events).
		Error

	if err != nil {
		return nil, err
	}

	return events, nil
}

func (s *Stage) FindExecutionByID(id uuid.UUID) (*StageExecution, error) {
	var execution StageExecution

	err := database.Conn().
		Where("id = ?", id).
		Where("stage_id = ?", s.ID).
		First(&execution).
		Error

	if err != nil {
		return nil, err
	}

	return &execution, nil
}

func ListStagesByIDs(ids []uuid.UUID) ([]Stage, error) {
	var stages []Stage

	err := database.Conn().
		Where("id IN ?", ids).
		Find(&stages).
		Error

	if err != nil {
		return nil, err
	}

	return stages, nil
}
