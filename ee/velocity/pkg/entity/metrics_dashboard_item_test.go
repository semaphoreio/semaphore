package entity

import (
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/semaphoreio/semaphore/velocity/pkg/database"
	"github.com/stretchr/testify/require"
)

var (
	dashboardId             = uuid.New()
	dashboardWithoutItemsId = uuid.New()
	branchNames             = []string{"master", "development"}
	orgId                   = uuid.New()
	projectId               = uuid.New()
)

func setup() error {
	database.Truncate("metrics_dashboard_items", "metrics_dashboards")

	conn := database.Conn()
	conn.Create(&MetricsDashboard{
		ID:             dashboardId,
		Name:           "Dashboard Test",
		ProjectId:      projectId,
		OrganizationId: orgId,
		InsertedAt:     time.Now(),
		UpdatedAt:      time.Now(),
	})

	conn.Create(&MetricsDashboard{
		ID:             dashboardWithoutItemsId,
		Name:           "Dashboard Empty",
		ProjectId:      projectId,
		OrganizationId: orgId,
		InsertedAt:     time.Now(),
		UpdatedAt:      time.Now(),
	})

	conn.Create(&MetricsDashboard{
		ID:             uuid.New(),
		Name:           "Dashboard Different Org",
		ProjectId:      projectId,
		OrganizationId: uuid.New(),
		InsertedAt:     time.Now(),
		UpdatedAt:      time.Now(),
	})

	for _, branchName := range branchNames {
		err := conn.Create(&MetricsDashboardItem{
			ID:                 uuid.New(),
			MetricsDashboardID: dashboardId,
			Name:               "Dashboard Item Test",
			BranchName:         branchName,
			PipelineFileName:   ".semaphore/velocity.yml",
			InsertedAt:         time.Now(),
			UpdatedAt:          time.Now(),
			Settings: ItemSettings{
				Metric: "METRIC_PERFORMANCE_COUNT",
				Goal:   "10",
			},
		}).Error

		if err != nil {
			return err
		}
	}

	return nil
}

func TestSaveMetricsDashboardItem(t *testing.T) {
	setup()
	t.Run("should not save dashboard item when missing MetricsDashboardId", func(t *testing.T) {
		item := &MetricsDashboardItem{Name: "Dashboard Item Test", BranchName: "master", PipelineFileName: ".semaphore/velocity.yml"}
		err := SaveMetricsDashboardItem(item)
		require.Error(t, err)
	})
	t.Run("should save dashboard metrics", func(t *testing.T) {
		item := &MetricsDashboardItem{
			ID:                 uuid.New(),
			MetricsDashboardID: dashboardId,
			Name:               "test",
			BranchName:         "Branch",
			PipelineFileName:   "file",
			Settings:           ItemSettings{Metric: "METRIC_PERFORMANCE_COUNT", Goal: "10"},
		}

		err := SaveMetricsDashboardItem(item)
		require.NoError(t, err)
	})
}

func TestUpdateMetricsDashboardItem(t *testing.T) {
	setup()
	t.Run("should update item", func(t *testing.T) {
		item := &MetricsDashboardItem{
			ID:                 uuid.New(),
			MetricsDashboardID: dashboardId,
			Name:               "test",
			BranchName:         "Branch",
			PipelineFileName:   "file",
			Settings:           ItemSettings{Metric: "METRIC_PERFORMANCE_COUNT", Goal: "10"},
		}

		err := SaveMetricsDashboardItem(item)
		require.NoError(t, err)

		item.Name = "test 2"
		err = UpdateMetricsDashboardItem(item.ID, "test 2")
		require.NoError(t, err)

		var updatedItem MetricsDashboardItem
		err = database.Conn().First(&updatedItem, item.ID).Error
		require.NoError(t, err)
		require.Equal(t, "test 2", updatedItem.Name)
	})
}

func TestDeleteMetricsDashboardItem(t *testing.T) {
	setup()
	t.Run("should delete item", func(t *testing.T) {
		item := &MetricsDashboardItem{
			ID:                 uuid.New(),
			MetricsDashboardID: dashboardId,
			Name:               "test",
			BranchName:         "Branch",
			PipelineFileName:   "file",
			Settings:           ItemSettings{Metric: "METRIC_PERFORMANCE_COUNT", Goal: "10"},
		}

		err := SaveMetricsDashboardItem(item)
		require.NoError(t, err)
		var before, after int64

		database.Conn().Model(&MetricsDashboardItem{}).Count(&before)
		err = DeleteMetricsDashboardItem(item.ID)
		require.NoError(t, err)
		database.Conn().Model(&MetricsDashboardItem{}).Count(&after)

		require.Equal(t, before-1, after)
		var deletedItem MetricsDashboardItem
		err = database.Conn().First(&deletedItem, item.ID).Error
		require.Error(t, err)
	})
}

func TestDashboardItemFindById(t *testing.T) {
	setup()
	item := &MetricsDashboardItem{
		ID:                 uuid.New(),
		MetricsDashboardID: dashboardId,
		Name:               "test",
		BranchName:         "Branch",
		PipelineFileName:   "file",
		Settings:           ItemSettings{Metric: "METRIC_PERFORMANCE", Goal: "10"},
	}

	err := SaveMetricsDashboardItem(item)
	require.NoError(t, err)

	t.Run("should return dashboard item", func(t *testing.T) {
		fetchedItem, err := DashboardItemFindById(item.ID)
		require.NoError(t, err)
		require.Equal(t, item.ID, fetchedItem.ID)
	})
	t.Run("should return error when item does not exist", func(t *testing.T) {
		_, err := DashboardItemFindById(uuid.New())
		require.Error(t, err)
	})
}
