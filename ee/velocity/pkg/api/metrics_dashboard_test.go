package api

import (
	"context"
	"fmt"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/semaphoreio/semaphore/velocity/pkg/database"
	"github.com/semaphoreio/semaphore/velocity/pkg/entity"
	pb "github.com/semaphoreio/semaphore/velocity/pkg/protos/velocity"
	"github.com/stretchr/testify/assert"
)

func setupDashboards(projectId, organizationId uuid.UUID) []*entity.MetricsDashboard {
	database.Truncate(entity.MetricsDashboard{}.TableName())

	dashboards := make([]*entity.MetricsDashboard, 0)
	for i := 0; i < 4; i++ {
		dashboards = append(dashboards,
			entity.MetricsDashboardFixture(fmt.Sprintf("dashboard-%d", i),
				entity.WithMetricsDashboardProjectId(projectId),
				entity.WithMetricsDashboardOrganizationId(organizationId),
			))
	}
	return dashboards
}

func Test_velocityService_DescribeMetricsDashboard(t *testing.T) {
	service := velocityService{}
	projectId := uuid.New()
	organizationId := uuid.New()

	dashboards := setupDashboards(projectId, organizationId)

	t.Run("return empty response when no dashboards", func(t *testing.T) {
		request := &pb.DescribeMetricsDashboardRequest{Id: uuid.NewString()}
		v, err := service.DescribeMetricsDashboard(context.Background(), request)
		assert.Nil(t, err)
		assert.NotNil(t, v)
		assert.Equal(t, emptyResponse(), v)
	})

	t.Run("return existing dashboard successfully", func(t *testing.T) {
		dashboard := dashboards[0]
		protoDashboard := dashboard.ToProto()

		request := &pb.DescribeMetricsDashboardRequest{Id: dashboard.ID.String()}
		v, err := service.DescribeMetricsDashboard(context.Background(), request)
		assert.Nil(t, err)
		assert.NotNil(t, v)
		assert.Equal(t, protoDashboard.Id, v.Dashboard.Id)
		assert.Equal(t, protoDashboard.Name, v.Dashboard.Name)
		assert.Equal(t, protoDashboard.ProjectId, v.Dashboard.ProjectId)
		assert.Equal(t, protoDashboard.OrganizationId, v.Dashboard.OrganizationId)
		assert.WithinDuration(t, protoDashboard.InsertedAt.AsTime().UTC(), v.Dashboard.InsertedAt.AsTime(), time.Second)
		assert.WithinDuration(t, protoDashboard.UpdatedAt.AsTime(), v.Dashboard.UpdatedAt.AsTime(), time.Second)

	})
}

func Test_velocityService_ListMetricsDashboards(t *testing.T) {
	service := velocityService{}
	projectId := uuid.New()
	organizationId := uuid.New()

	database.Truncate(entity.MetricsDashboard{}.TableName())

	dashboards := setupDashboards(projectId, organizationId)

	t.Run("return empty response when no dashboards", func(t *testing.T) {
		request := &pb.ListMetricsDashboardsRequest{ProjectId: uuid.NewString()}
		v, err := service.ListMetricsDashboards(context.Background(), request)
		assert.Nil(t, err)
		assert.NotNil(t, v)
		assert.Equal(t, emptyListResponse(), v)
	})

	t.Run("return existing dashboards successfully", func(t *testing.T) {
		request := &pb.ListMetricsDashboardsRequest{ProjectId: projectId.String()}
		v, err := service.ListMetricsDashboards(context.Background(), request)
		assert.Nil(t, err)
		assert.NotNil(t, v)
		assert.Equal(t, len(dashboards), len(v.Dashboards))
	})
}

func emptyResponse() *pb.DescribeMetricsDashboardResponse {
	return &pb.DescribeMetricsDashboardResponse{Dashboard: &pb.MetricsDashboard{}}
}

func emptyListResponse() *pb.ListMetricsDashboardsResponse {
	return &pb.ListMetricsDashboardsResponse{Dashboards: []*pb.MetricsDashboard{}}
}

func Test_velocityService_DeleteMetricsDashboard(t *testing.T) {
	service := velocityService{}
	projectId := uuid.New()
	organizationId := uuid.New()

	dashboards := setupDashboards(projectId, organizationId)

	t.Run("when dashboard does not exists do not delete anything", func(t *testing.T) {
		request := &pb.DeleteMetricsDashboardRequest{Id: uuid.NewString()}
		var before, after int64

		database.Conn().Model(&entity.MetricsDashboard{}).Count(&before)
		v, err := service.DeleteMetricsDashboard(context.Background(), request)
		database.Conn().Model(&entity.MetricsDashboard{}).Count(&after)
		assert.Nil(t, err)
		assert.NotNil(t, v)
		assert.Equal(t, before, after)
	})
	t.Run("when dashboard exists delete it", func(t *testing.T) {
		request := &pb.DeleteMetricsDashboardRequest{Id: dashboards[0].ID.String()}
		var before, after int64

		database.Conn().Model(&entity.MetricsDashboard{}).Count(&before)
		v, err := service.DeleteMetricsDashboard(context.Background(), request)
		database.Conn().Model(&entity.MetricsDashboard{}).Count(&after)
		assert.Nil(t, err)
		assert.NotNil(t, v)
		assert.Equal(t, before-1, after)
	})

}

func Test_velocityService_CreateMetricsDashboard(t *testing.T) {
	database.Truncate(entity.MetricsDashboard{}.TableName())
	service := velocityService{}
	projectId := uuid.New()
	organizationId := uuid.New()

	t.Run("when dashboard name is empty return error", func(t *testing.T) {
		request := &pb.CreateMetricsDashboardRequest{Name: "", ProjectId: projectId.String(), OrganizationId: organizationId.String()}
		var before, after int64

		database.Conn().Model(&entity.MetricsDashboard{}).Count(&before)
		v, err := service.CreateMetricsDashboard(context.Background(), request)
		database.Conn().Model(&entity.MetricsDashboard{}).Count(&after)
		assert.Nil(t, v)
		assert.Error(t, err)
		assert.Equal(t, before, after)
	})
	t.Run("create dashboard successfully", func(t *testing.T) {
		request := &pb.CreateMetricsDashboardRequest{Name: "test", ProjectId: projectId.String(), OrganizationId: organizationId.String()}
		var before, after int64

		database.Conn().Model(&entity.MetricsDashboard{}).Count(&before)
		v, err := service.CreateMetricsDashboard(context.Background(), request)
		database.Conn().Model(&entity.MetricsDashboard{}).Count(&after)
		assert.Nil(t, err)
		assert.NotNil(t, v)
		assert.Equal(t, before+1, after)
	})
}

func Test_velocityService_UpdateMetricsDashboard(t *testing.T) {
	service := velocityService{}
	projectId := uuid.New()
	organizationId := uuid.New()

	dashboards := setupDashboards(projectId, organizationId)

	t.Run("when dashboard does not exists return empty", func(t *testing.T) {
		request := &pb.UpdateMetricsDashboardRequest{Id: uuid.NewString(), Name: "test"}
		v, err := service.UpdateMetricsDashboard(context.Background(), request)
		assert.NotNil(t, v)
		assert.NoError(t, err)
	})
	t.Run("when dashboard name is empty return error", func(t *testing.T) {
		request := &pb.UpdateMetricsDashboardRequest{Id: dashboards[0].ID.String(), Name: ""}
		v, err := service.UpdateMetricsDashboard(context.Background(), request)
		assert.Nil(t, v)
		assert.Error(t, err)
	})
	t.Run("update dashboard successfully", func(t *testing.T) {
		request := &pb.UpdateMetricsDashboardRequest{Id: dashboards[0].ID.String(), Name: "Updated test"}
		var before, after int64

		database.Conn().Model(&entity.MetricsDashboard{}).Count(&before)
		v, err := service.UpdateMetricsDashboard(context.Background(), request)
		database.Conn().Model(&entity.MetricsDashboard{}).Count(&after)

		assert.Equal(t, before, after)
		assert.NoError(t, err)
		assert.NotNil(t, v)
	})
}
