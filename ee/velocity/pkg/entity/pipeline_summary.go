package entity

import (
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/semaphoreio/semaphore/velocity/pkg/database"
	pb "github.com/semaphoreio/semaphore/velocity/pkg/protos/velocity"
)

type PipelineSummary struct {
	ProjectID  uuid.UUID
	PipelineID uuid.UUID
	Total      int
	Passed     int
	Skipped    int
	Errors     int
	Failed     int
	Disabled   int
	Duration   time.Duration
	CreatedAt  time.Time
	UpdatedAt  time.Time
}

func (PipelineSummary) TableName() string {
	return "pipeline_summaries"
}

func (s *PipelineSummary) toProto() *pb.PipelineSummary {
	result := &pb.PipelineSummary{}
	result.PipelineId = s.PipelineID.String()
	result.Summary = &pb.Summary{
		Total:    int32(s.Total),
		Passed:   int32(s.Passed),
		Skipped:  int32(s.Skipped),
		Error:    int32(s.Errors),
		Failed:   int32(s.Failed),
		Disabled: int32(s.Disabled),
		Duration: s.Duration.Nanoseconds(),
	}

	return result
}

type PipelineSummaries []PipelineSummary

func (ps PipelineSummaries) ToProto() []*pb.PipelineSummary {
	result := make([]*pb.PipelineSummary, 0)
	for _, summary := range ps {
		result = append(result, summary.toProto())
	}

	return result
}

// SavePipelineSummary stores pipeline summary into the database
func SavePipelineSummary(summary *PipelineSummary) error {
	query := database.Conn()

	err := query.Create(summary).Error
	if err != nil {
		if strings.Contains(err.Error(), "duplicate key value violates unique constraint") {
			return fmt.Errorf("pipeline id must by unique for a specific project")
		}

		return err
	}

	return nil
}

// ListPipelineSummaries lists all pipeline summaries by project identifier.
func ListPipelineSummaries(projectID uuid.UUID) ([]PipelineSummary, error) {
	var summaries []PipelineSummary

	query := database.Conn().Where("project_id = ?", projectID)

	err := query.Find(&summaries).Error
	if err != nil {
		return []PipelineSummary{}, err
	}

	return summaries, nil
}

// ListPipelineSummariesBy pipeline ids lists all pipeline summaries.
func ListPipelineSummariesBy(pipelineIDs []string) (PipelineSummaries, error) {
	var summaries []PipelineSummary

	query := database.Conn().Where("pipeline_id IN ?", pipelineIDs)

	err := query.Find(&summaries).Error
	if err != nil {
		return []PipelineSummary{}, err
	}

	return summaries, nil
}

// FindPipelineSummary fetches the pipeline summary by pipeline identifier.
func FindPipelineSummary(pipelineID uuid.UUID) (PipelineSummary, error) {
	var summary PipelineSummary

	query := database.Conn().Where("pipeline_id = ?", pipelineID)

	err := query.First(&summary).Error
	if err != nil {
		return PipelineSummary{}, err
	}

	return summary, nil
}
