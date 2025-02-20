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

func Test_velocityService_ListPipelinePerformanceMetrics(t *testing.T) {
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
		request := buildPerformanceRequest(uuid.New(), now, branchName, pb.MetricAggregation_DAILY)
		v, err := service.ListPipelinePerformanceMetrics(context.Background(), request)
		assert.NotNil(t, v)
		assert.Nil(t, err)
		assert.Equal(t, 0, len(v.AllMetrics))
	})

	t.Run("return metrics for the last 7 days", func(t *testing.T) {
		request := buildPerformanceRequest(projectId, now, branchName, pb.MetricAggregation_DAILY)
		v, err := service.ListPipelinePerformanceMetrics(context.Background(), request)
		assert.NotNil(t, v)
		assert.Nil(t, err)
		assert.Equal(t, 7, len(v.AllMetrics))
	})

	t.Run("return metrics for the last 7 days for range", func(t *testing.T) {
		request := buildPerformanceRequest(projectId, now, "master", pb.MetricAggregation_RANGE)
		v, err := service.ListPipelinePerformanceMetrics(context.Background(), request)
		assert.NotNil(t, v)
		assert.Nil(t, err)
		assert.Equal(t, 1, len(v.AllMetrics))
	})

}

func buildPerformanceRequest(projectId uuid.UUID, now time.Time, branchName string, aggregate pb.MetricAggregation) *pb.ListPipelinePerformanceMetricsRequest {
	return &pb.ListPipelinePerformanceMetricsRequest{
		ProjectId:        projectId.String(),
		PipelineFileName: ".semaphore/semaphore.yml",
		BranchName:       branchName,
		Aggregate:        aggregate,
		FromDate:         timestamppb.New(now.AddDate(0, 0, -6)),
		ToDate:           timestamppb.New(now),
	}
}
