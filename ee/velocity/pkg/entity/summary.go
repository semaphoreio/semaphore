package entity

import (
	"github.com/google/uuid"
	"time"
)

type Summary struct {
	Total    int
	Passed   int
	Skipped  int
	Error    int
	Failed   int
	Disabled int
	Duration time.Duration
}

func (s *Summary) ToPipelineSummary(projectID, pipelineID uuid.UUID) PipelineSummary {
	return PipelineSummary{
		ProjectID:  projectID,
		PipelineID: pipelineID,
		Total:      s.Total,
		Passed:     s.Passed,
		Skipped:    s.Skipped,
		Errors:     s.Error,
		Failed:     s.Failed,
		Disabled:   s.Disabled,
		Duration:   s.Duration,
	}
}

func (s *Summary) ToJobSummary(projectID, pipelineID, jobID uuid.UUID) JobSummary {
	return JobSummary{
		ProjectID:  projectID,
		PipelineID: pipelineID,
		JobID:      jobID,
		Total:      s.Total,
		Passed:     s.Passed,
		Skipped:    s.Skipped,
		Errors:     s.Error,
		Failed:     s.Failed,
		Disabled:   s.Disabled,
		Duration:   s.Duration,
	}
}
