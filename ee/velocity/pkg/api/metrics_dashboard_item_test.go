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

func Test_velocityService_CreateDashboardItem(t *testing.T) {
	service := velocityService{}
	dashboards := setupDashboards(uuid.New(), uuid.New())
	dashboard := dashboards[0]

	t.Run("return error when name is empty", func(t *testing.T) {
		request := buildCreateRequest(dashboard.ID.String(), "")
		var before, after int64
		query := database.Conn().Model(&entity.MetricsDashboardItem{})

		query.Count(&before)
		v, err := service.CreateDashboardItem(context.Background(), request)
		query.Count(&after)
		assert.Nil(t, v)
		assert.Error(t, err)
		assert.Equal(t, before, after)
	})

	t.Run("create dashboard item successfully", func(t *testing.T) {
		request := buildCreateRequest(dashboard.ID.String(), "item-1")
		var before, after int64
		query := database.Conn().Model(&entity.MetricsDashboardItem{})

		query.Count(&before)
		v, err := service.CreateDashboardItem(context.Background(), request)
		query.Count(&after)

		assert.Equal(t, before+1, after)
		assert.Nil(t, err)
		assert.NotNil(t, v)
		assert.NotEmpty(t, v.Item.Id)
		assert.Equal(t, request.Name, v.Item.Name)
		assert.Equal(t, request.MetricsDashboardId, v.Item.MetricsDashboardId)
		assert.Equal(t, request.PipelineFileName, v.Item.PipelineFileName)
		assert.Equal(t, request.BranchName, v.Item.BranchName)
		assert.Equal(t, request.Settings.Metric, v.Item.Settings.Metric)
		assert.Equal(t, request.Settings.Goal, v.Item.Settings.Goal)
		assert.Equal(t, request.Notes, v.Item.Notes)
	})
}

func Test_velocityService_UpdateDashboardItem(t *testing.T) {
	service := velocityService{}
	dashboards := setupDashboards(uuid.New(), uuid.New())
	dashboard := dashboards[0]

	t.Run("return error when name is empty", func(t *testing.T) {
		item := createDashboardItem(dashboard.ID, "item-1")

		request := &pb.UpdateDashboardItemRequest{
			Id:   item.ID.String(),
			Name: "",
		}

		var before, after int64
		query := database.Conn().Model(&entity.MetricsDashboardItem{})

		query.Count(&before)
		v, err := service.UpdateDashboardItem(context.Background(), request)
		query.Count(&after)

		assert.Nil(t, v)
		assert.Error(t, err)
		assert.Equal(t, before, after)
		var updatedItem entity.MetricsDashboardItem
		err = query.Where("id", item.ID).First(&updatedItem).Error
		if err == nil {
			assert.Equal(t, item.Name, updatedItem.Name)
		}

	})
	t.Run("update dashboard item successfully", func(t *testing.T) {
		item := createDashboardItem(dashboard.ID, "item-1")

		request := &pb.UpdateDashboardItemRequest{
			Id:   item.ID.String(),
			Name: "item-2",
		}

		var before, after int64
		query := database.Conn().Model(&entity.MetricsDashboardItem{})

		query.Count(&before)
		v, err := service.UpdateDashboardItem(context.Background(), request)
		query.Count(&after)

		assert.Equal(t, before, after)
		assert.Nil(t, err)
		assert.NotNil(t, v)

		var updatedItem entity.MetricsDashboardItem
		err = query.Where("id", item.ID).First(&updatedItem).Error
		if err == nil {
			assert.Equal(t, request.Name, updatedItem.Name)
		}
	})

}

func Test_velocityService_DeleteDashboardItem(t *testing.T) {
	service := velocityService{}
	dashboards := setupDashboards(uuid.New(), uuid.New())
	dashboard := dashboards[0]

	t.Run("do not delete anything if used wrong id", func(t *testing.T) {
		request := &pb.DeleteDashboardItemRequest{Id: uuid.NewString()}

		var before, after int64
		query := database.Conn().Model(&entity.MetricsDashboardItem{})

		query.Count(&before)
		v, err := service.DeleteDashboardItem(context.Background(), request)
		query.Count(&after)

		assert.Equal(t, before, after)
		assert.NotNil(t, v)
		assert.NoError(t, err)
	})

	t.Run("delete dashboard item successfully", func(t *testing.T) {

		item := createDashboardItem(dashboard.ID, "item-1")
		request := &pb.DeleteDashboardItemRequest{Id: item.ID.String()}

		var before, after int64
		query := database.Conn().Model(&entity.MetricsDashboardItem{})

		query.Count(&before)
		v, err := service.DeleteDashboardItem(context.Background(), request)
		query.Count(&after)

		assert.Equal(t, before-1, after)
		assert.NotNil(t, v)
		assert.NoError(t, err)

	})
}

func Test_velocityService_ChangeDashboardItemNotes(t *testing.T) {
	service := velocityService{}
	dashboards := setupDashboards(uuid.New(), uuid.New())
	dashboard := dashboards[0]

	t.Run("update dashboard item notes successfully", func(t *testing.T) {
		item := createDashboardItem(dashboard.ID, "item-1")

		request := &pb.ChangeDashboardItemNotesRequest{
			Id:    item.ID.String(),
			Notes: "Updated notes",
		}

		var before, after int64
		query := database.Conn().Model(&entity.MetricsDashboardItem{})

		query.Count(&before)
		v, err := service.ChangeDashboardItemNotes(context.Background(), request)
		query.Count(&after)

		assert.Equal(t, before, after)
		assert.Nil(t, err)
		assert.NotNil(t, v)

		var updatedItem entity.MetricsDashboardItem
		err = query.Where("id", item.ID).First(&updatedItem).Error
		if err == nil {
			assert.Equal(t, request.Notes, updatedItem.Notes)
		}
	})

}

func buildCreateRequest(dashboardId, name string) *pb.CreateDashboardItemRequest {
	return &pb.CreateDashboardItemRequest{
		Name:               name,
		MetricsDashboardId: dashboardId,
		PipelineFileName:   "pipeline.yml",
		BranchName:         "main",
		Notes:              "notes",
		Settings:           &pb.DashboardItemSettings{Metric: pb.Metric_METRIC_PERFORMANCE, Goal: "10"},
	}
}

func createDashboardItem(dashboardId uuid.UUID, name string) *entity.MetricsDashboardItem {
	item := &entity.MetricsDashboardItem{
		Name:               name,
		MetricsDashboardID: dashboardId,
		PipelineFileName:   "pipeline.yml",
		BranchName:         "main",
		Notes:              "notes",
		Settings:           entity.ItemSettings{Metric: "METRIC_PERFORMANCE", Goal: "10"},
	}

	if err := database.Conn().Create(item).Error; err != nil {
		panic(err)
	}

	return item
}
