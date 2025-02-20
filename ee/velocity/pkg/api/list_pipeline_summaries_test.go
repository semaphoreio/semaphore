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

func Test_velocityService_ListPipelineSummaries(t *testing.T) {
	service := velocityService{}
	database.Truncate("pipeline_summaries")
	pipelineIDs := []string{uuid.New().String(), uuid.New().String()}

	for _, pplId := range pipelineIDs {
		CreateDummyPipelineSummary(uuid.New(), uuid.MustParse(pplId))
	}

	t.Run("return empty value when no summary", func(t *testing.T) {
		v, err := service.ListPipelineSummaries(context.Background(), &pb.ListPipelineSummariesRequest{
			PipelineIds: []string{uuid.New().String()},
		})
		assert.NotNil(t, v)
		assert.NoError(t, err)
		assert.Equal(t, 0, len(v.PipelineSummaries))
	})

	t.Run("return pipeline summaries", func(t *testing.T) {
		v, err := service.ListPipelineSummaries(context.Background(), &pb.ListPipelineSummariesRequest{
			PipelineIds: pipelineIDs,
		})
		assert.NotNil(t, v)
		assert.NoError(t, err)
		assert.Equal(t, 2, len(v.PipelineSummaries))

		assert.Equal(t, pipelineIDs[0], v.PipelineSummaries[0].PipelineId)
		assert.Equal(t, int32(1), v.PipelineSummaries[0].Summary.Total)
		assert.Equal(t, int32(1), v.PipelineSummaries[0].Summary.Passed)
		assert.Equal(t, int32(1), v.PipelineSummaries[0].Summary.Skipped)
		assert.Equal(t, int32(0), v.PipelineSummaries[0].Summary.Error)
		assert.Equal(t, int32(1), v.PipelineSummaries[0].Summary.Failed)
		assert.Equal(t, int32(1), v.PipelineSummaries[0].Summary.Disabled)
		assert.Equal(t, int64(1), v.PipelineSummaries[0].Summary.Duration)

		assert.Equal(t, pipelineIDs[1], v.PipelineSummaries[1].PipelineId)
		assert.Equal(t, int32(1), v.PipelineSummaries[1].Summary.Total)
		assert.Equal(t, int32(1), v.PipelineSummaries[1].Summary.Passed)
		assert.Equal(t, int32(1), v.PipelineSummaries[1].Summary.Skipped)
		assert.Equal(t, int32(0), v.PipelineSummaries[1].Summary.Error)
		assert.Equal(t, int32(1), v.PipelineSummaries[1].Summary.Failed)
		assert.Equal(t, int32(1), v.PipelineSummaries[1].Summary.Disabled)
		assert.Equal(t, int64(1), v.PipelineSummaries[1].Summary.Duration)

	})

}

func CreateDummyPipelineSummary(projectId, pipelineId uuid.UUID) *entity.PipelineSummary {
	summary := &entity.PipelineSummary{
		ProjectID:  projectId,
		PipelineID: pipelineId,
		Total:      1,
		Passed:     1,
		Skipped:    1,
		Errors:     0,
		Failed:     1,
		Disabled:   1,
		Duration:   1,
	}

	if err := entity.SavePipelineSummary(summary); err != nil {
		panic(err)
	}

	return summary
}
