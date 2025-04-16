package events

import (
	"time"

	"github.com/semaphoreio/semaphore/delivery-hub/pkg/models"
)

//
// This is the event that is emitted when a stage finishes its execution.
//

const (
	StageExecutionCompletionType = "StageExecutionCompletion"
)

type StageExecutionCompletion struct {
	Type           string          `json:"type"`
	Stage          *Stage          `json:"stage,omitempty"`
	StageExecution *StageExecution `json:"stage_execution,omitempty"`
}

type Stage struct {
	ID string `json:"id"`
}

type StageExecution struct {
	ID         string     `json:"id"`
	Result     string     `json:"result"`
	CreatedAt  *time.Time `json:"created_at,omitempty"`
	StartedAt  *time.Time `json:"started_at,omitempty"`
	FinishedAt *time.Time `json:"finished_at,omitempty"`
}

func NewStageExecutionCompletion(execution *models.StageExecution) *StageExecutionCompletion {
	return &StageExecutionCompletion{
		Type: StageExecutionCompletionType,
		Stage: &Stage{
			ID: execution.StageID.String(),
		},
		StageExecution: &StageExecution{
			ID:         execution.ID.String(),
			Result:     execution.Result,
			CreatedAt:  execution.CreatedAt,
			StartedAt:  execution.StartedAt,
			FinishedAt: execution.FinishedAt,
		},
	}
}
