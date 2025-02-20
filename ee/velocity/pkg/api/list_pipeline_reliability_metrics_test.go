package api

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/semaphoreio/semaphore/velocity/pkg/database"
	"github.com/semaphoreio/semaphore/velocity/pkg/entity"
	pb "github.com/semaphoreio/semaphore/velocity/pkg/protos/velocity"
	"github.com/stretchr/testify/assert"
	"google.golang.org/protobuf/types/known/timestamppb"
)

func Test_velocityService_ListPipelineReliabilityMetrics(t *testing.T) {
	service := velocityService{}
	projectId := uuid.New()
	organizationId := uuid.New()
	now := time.Now()
	branchName := "master"
	database.Truncate(entity.ProjectMetrics{}.TableName())
	metrics := make([]*entity.ProjectMetrics, 0)
	for i := 0; i <= 30; i++ {
		daysAgo := time.Now().AddDate(0, 0, -i)

		metrics = append(metrics, entity.ProjectMetricFixture(
			entity.WithProjectMetricProjectId(projectId),
			entity.WithProjectMetricBranchName(branchName),
			entity.WithProjectMetricOrganizationId(organizationId),
			entity.WithProjectMetricPipelineFileName(".semaphore/semaphore.yml"),
			entity.WithProjectMetricCollectedAt(daysAgo),
		))
	}

	t.Run("return empty value when no metric", func(t *testing.T) {
		request := buildRequest(uuid.New(), now, "", pb.MetricAggregation_DAILY)

		v, err := service.ListPipelineReliabilityMetrics(context.Background(), request)
		assert.NotNil(t, v)
		assert.Nil(t, err)
		assert.Equal(t, 0, len(v.Metrics))
	})

	t.Run("return project metrics successfully for specific branch", func(t *testing.T) {
		request := buildRequest(projectId, now, branchName, pb.MetricAggregation_DAILY)
		pm, err := service.ListPipelineReliabilityMetrics(context.Background(), request)
		assert.NoError(t, err)
		assert.NotNil(t, pm)
		assert.Equal(t, 7, len(pm.Metrics))
	})

	t.Run("return metrics successfully for range aggregation", func(t *testing.T) {
		request := buildRequest(projectId, now, "", pb.MetricAggregation_RANGE)
		pm, err := service.ListPipelineReliabilityMetrics(context.Background(), request)
		assert.NoError(t, err)
		assert.NotNil(t, pm)
		assert.Equal(t, 1, len(pm.Metrics))
	})

}

func buildRequest(projectId uuid.UUID, now time.Time, branchName string, aggregate pb.MetricAggregation) *pb.ListPipelineReliabilityMetricsRequest {
	return &pb.ListPipelineReliabilityMetricsRequest{
		ProjectId:        projectId.String(),
		PipelineFileName: ".semaphore/semaphore.yml",
		BranchName:       branchName,
		Aggregate:        aggregate,
		FromDate:         timestamppb.New(now.AddDate(0, 0, -6)),
		ToDate:           timestamppb.New(now),
	}
}
