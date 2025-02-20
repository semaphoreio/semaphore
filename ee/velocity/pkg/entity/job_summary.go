package entity

import (
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/semaphoreio/semaphore/velocity/pkg/database"
	pb "github.com/semaphoreio/semaphore/velocity/pkg/protos/velocity"
)

type JobSummary struct {
	ProjectID  uuid.UUID
	PipelineID uuid.UUID
	JobID      uuid.UUID
	Total      int
	Passed     int
	Skipped    int
	Errors     int
	Failed     int
	Disabled   int
	Duration   time.Duration
}

func (JobSummary) TableName() string {
	return "job_summaries"
}

func (s *JobSummary) toProto() *pb.JobSummary {
	result := &pb.JobSummary{}
	result.PipelineId = s.PipelineID.String()
	result.JobId = s.JobID.String()
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

type JobSummaries []JobSummary

func (ps JobSummaries) ToProto() []*pb.JobSummary {
	result := make([]*pb.JobSummary, 0)
	for _, summary := range ps {
		result = append(result, summary.toProto())
	}

	return result
}

// SaveJobSummary stores job summary into the database
func SaveJobSummary(summary *JobSummary) error {
	query := database.Conn()

	err := query.Create(summary).Error
	if err != nil {
		if strings.Contains(err.Error(), "duplicate key value violates unique constraint") {
			return fmt.Errorf("job id must be unique for a specific project")
		}

		return err
	}

	return nil
}

// ListJobSummariesByProject lists all job summaries by project identifier.
func ListJobSummariesByProject(projectID uuid.UUID) ([]JobSummary, error) {
	var summaries []JobSummary

	query := database.Conn().Where("project_id = ?", projectID).Order("created_at asc")

	err := query.Find(&summaries).Error
	if err != nil {
		return []JobSummary{}, err
	}

	return summaries, nil
}

// ListJobSummariesByPipeline lists all job summaries by pipeline identifier.
func ListJobSummariesByPipeline(pipelineID uuid.UUID) ([]JobSummary, error) {
	var summaries []JobSummary

	query := database.Conn().Where("pipeline_id = ?", pipelineID).Order("created_at asc")

	err := query.Find(&summaries).Error
	if err != nil {
		return []JobSummary{}, err
	}

	return summaries, nil
}

// ListJobSummaries job ids lists all job summaries in the specified list.
func ListJobSummaries(jobIDs []string) (JobSummaries, error) {
	var summaries []JobSummary

	query := database.Conn().Where("job_id IN ?", jobIDs).Order("created_at asc")

	err := query.Find(&summaries).Error
	if err != nil {
		return []JobSummary{}, err
	}

	return summaries, nil
}

// FindJobSummary fetches the job summary by job identifier.
func FindJobSummary(jobID uuid.UUID) (JobSummary, error) {
	var summary JobSummary

	query := database.Conn().Where("job_id = ?", jobID)

	err := query.First(&summary).Error
	if err != nil {
		return JobSummary{}, err
	}

	return summary, nil
}
