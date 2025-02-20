package api

import (
	"context"
	"testing"

	"github.com/google/uuid"
	"github.com/semaphoreio/semaphore/velocity/pkg/database"
	"github.com/semaphoreio/semaphore/velocity/pkg/entity"
	pb "github.com/semaphoreio/semaphore/velocity/pkg/protos/velocity"
	"github.com/stretchr/testify/assert"
)

func Test_velocityService_ListJobSummaries(t *testing.T) {
	service := velocityService{}
	JobIDs := []string{uuid.New().String(), uuid.New().String()}
	database.Truncate("job_summaries")
	for _, jobId := range JobIDs {
		CreateDummyJobSummary(uuid.New(), uuid.New(), uuid.MustParse(jobId))
	}
	t.Run("return empty value when no summary", func(t *testing.T) {
		v, err := service.ListJobSummaries(context.Background(), &pb.ListJobSummariesRequest{
			JobIds: []string{uuid.New().String()},
		})
		assert.NotNil(t, v)
		assert.NoError(t, err)
		assert.Equal(t, 0, len(v.JobSummaries))
	})

	t.Run("return job summaries", func(t *testing.T) {
		v, err := service.ListJobSummaries(context.Background(), &pb.ListJobSummariesRequest{
			JobIds: JobIDs,
		})
		assert.NotNil(t, v)
		assert.NoError(t, err)
		assert.Equal(t, 2, len(v.JobSummaries))
		assert.Equal(t, JobIDs[0], v.JobSummaries[0].JobId)

		assert.Equal(t, int32(1), v.JobSummaries[0].Summary.Total)
		assert.Equal(t, int32(1), v.JobSummaries[0].Summary.Passed)
		assert.Equal(t, int32(1), v.JobSummaries[0].Summary.Skipped)
		assert.Equal(t, int32(0), v.JobSummaries[0].Summary.Error)
		assert.Equal(t, int32(1), v.JobSummaries[0].Summary.Failed)
		assert.Equal(t, int32(1), v.JobSummaries[0].Summary.Disabled)
		assert.Equal(t, int64(1), v.JobSummaries[0].Summary.Duration)

		assert.Equal(t, JobIDs[1], v.JobSummaries[1].JobId)
		assert.Equal(t, int32(1), v.JobSummaries[1].Summary.Total)
		assert.Equal(t, int32(1), v.JobSummaries[1].Summary.Passed)
		assert.Equal(t, int32(1), v.JobSummaries[1].Summary.Skipped)
		assert.Equal(t, int32(0), v.JobSummaries[1].Summary.Error)
		assert.Equal(t, int32(1), v.JobSummaries[1].Summary.Failed)
		assert.Equal(t, int32(1), v.JobSummaries[1].Summary.Disabled)
		assert.Equal(t, int64(1), v.JobSummaries[1].Summary.Duration)
	})

}

func CreateDummyJobSummary(projectId, pipelineId, jobId uuid.UUID) *entity.JobSummary {
	summary := &entity.JobSummary{
		ProjectID:  projectId,
		PipelineID: pipelineId,
		JobID:      jobId,
		Total:      1,
		Passed:     1,
		Skipped:    1,
		Errors:     0,
		Failed:     1,
		Disabled:   1,
		Duration:   1,
	}

	if err := entity.SaveJobSummary(summary); err != nil {
		panic(err)
	}

	return summary
}
