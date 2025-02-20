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
	"github.com/stretchr/testify/require"
	"google.golang.org/protobuf/types/known/timestamppb"
)

func Test_velocityService_ListPipelineFrequencyMetrics(t *testing.T) {
	service := velocityService{}
	projectId := uuid.New()
	organizationId := uuid.New()
	now := time.Now()
	branchName := "master"
	database.Truncate(entity.ProjectMetrics{}.TableName())
	metrics := make([]*entity.ProjectMetrics, 0)
	setup(metrics, projectId, branchName, organizationId)

	t.Run("throw error when pipeline file name is empty", func(t *testing.T) {
		fromThirtyDaysAgo := timestamppb.New(time.Now().AddDate(0, 0, -30))
		toNow := timestamppb.New(now)
		request := &pb.ListPipelineFrequencyMetricsRequest{
			ProjectId:        projectId.String(),
			PipelineFileName: "",
			BranchName:       "master",
			Aggregate:        pb.MetricAggregation_DAILY,
			FromDate:         fromThirtyDaysAgo,
			ToDate:           toNow,
		}

		emptyResult, err := service.ListPipelineFrequencyMetrics(context.Background(), request)
		require.NoError(t, err)
		require.NotNil(t, emptyResult)
		require.Equal(t, 1, len(emptyResult.Metrics))
		assert.Equal(t, emptyResult.Metrics[0], &pb.FrequencyMetric{
			FromDate: fromThirtyDaysAgo,
			ToDate:   toNow,
			AllCount: 0,
		})
	})

	t.Run("return empty value when no metric for branch", func(t *testing.T) {
		request := buildFrequencyRequest(uuid.New(), now, "wrong-branch", pb.MetricAggregation_DAILY)

		v, err := service.ListPipelineFrequencyMetrics(context.Background(), request)
		assert.NotNil(t, v)
		assert.Nil(t, err)
		assert.Equal(t, 0, len(v.Metrics))

	})

	t.Run("return values for correct branch", func(t *testing.T) {
		request := buildFrequencyRequest(projectId, now, branchName, pb.MetricAggregation_RANGE)

		v, err := service.ListPipelineFrequencyMetrics(context.Background(), request)
		assert.NotNil(t, v)
		assert.NoError(t, err)

		assert.Equal(t, 1, len(v.Metrics))
	})

}

func setup(metrics []*entity.ProjectMetrics, projectId uuid.UUID, branchName string, organizationId uuid.UUID) {
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
}

func buildFrequencyRequest(projectId uuid.UUID, now time.Time, branchName string, aggregate pb.MetricAggregation) *pb.ListPipelineFrequencyMetricsRequest {
	return &pb.ListPipelineFrequencyMetricsRequest{
		ProjectId:        projectId.String(),
		PipelineFileName: ".semaphore/semaphore.yml",
		BranchName:       branchName,
		Aggregate:        aggregate,
		FromDate:         timestamppb.New(now.AddDate(0, 0, -6)),
		ToDate:           timestamppb.New(now),
	}
}
