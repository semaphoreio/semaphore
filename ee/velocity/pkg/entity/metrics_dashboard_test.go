package entity

import (
	"testing"

	"github.com/google/uuid"
	"github.com/semaphoreio/semaphore/velocity/pkg/database"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestFindMetricsDashboardById(t *testing.T) {

	err := setup()
	require.NoError(t, err)

	t.Run("should list dashboard metrics items for dashboard", func(t *testing.T) {
		dashboard, err := FindMetricsDashboardById(dashboardId)
		require.NoError(t, err)
		items := dashboard.Items
		require.Len(t, items, 2)
		assert.Contains(t, branchNames, items[0].BranchName)
		assert.Contains(t, branchNames, items[1].BranchName)
		assert.Equal(t, items[0].PipelineFileName, ".semaphore/velocity.yml")
		assert.Equal(t, items[1].PipelineFileName, ".semaphore/velocity.yml")
		assert.Equal(t, items[0].MetricsDashboardID, dashboardId)
		assert.Equal(t, items[1].MetricsDashboardID, dashboardId)
	})
	t.Run("should return empty when no items found for dashboard", func(t *testing.T) {
		dashboard, err := FindMetricsDashboardById(dashboardWithoutItemsId)
		require.NoError(t, err)
		require.Len(t, dashboard.Items, 0)
	})

	t.Run("should return error when dashboard not found", func(t *testing.T) {
		_, err := FindMetricsDashboardById(uuid.New())
		require.Error(t, err)
	})
}

func TestDeleteMetricsDashboardById(t *testing.T) {
	err := setup()
	require.NoError(t, err)

	t.Run("should delete dashboard metrics for dashboard", func(t *testing.T) {
		conn := database.Conn()
		var beforeDeleteCount int64
		conn.Model(&MetricsDashboard{}).
			Where("id = ?", dashboardId).
			Count(&beforeDeleteCount)

		err := DeleteMetricsDashboardById(dashboardId)
		require.NoError(t, err)
		_, err = FindMetricsDashboardById(dashboardId)
		require.Error(t, err)

		var afterDeleteCount int64
		conn.Model(&MetricsDashboard{}).
			Where("id = ?", dashboardId).
			Count(&afterDeleteCount)

		assert.Less(t, afterDeleteCount, beforeDeleteCount)
		assert.Equal(t, afterDeleteCount, beforeDeleteCount-1)
	})

}

func TestDeleteMetricsDashboardsByOrganizationId(t *testing.T) {
	err := setup()
	require.NoError(t, err)

	t.Run("should delete dashboard metrics by org", func(t *testing.T) {
		conn := database.Conn()
		var beforeDeleteCount int64
		conn.Model(&MetricsDashboard{}).
			Count(&beforeDeleteCount)

		err := DeleteMetricsDashboardsByOrganizationId(orgId)
		require.NoError(t, err)
		_, err = FindMetricsDashboardById(orgId)
		require.Error(t, err)

		var afterDeleteCount int64
		conn.Model(&MetricsDashboard{}).
			Count(&afterDeleteCount)

		assert.Less(t, afterDeleteCount, beforeDeleteCount)
		assert.Greater(t, afterDeleteCount, int64(0))
	})

}

func TestSaveMetricsDashboard(t *testing.T) {
	t.Run("should save dashboard metrics", func(t *testing.T) {
		conn := database.Conn()
		var beforeSaveCount int64
		conn.Model(&MetricsDashboard{}).
			Count(&beforeSaveCount)
		dashboard := &MetricsDashboard{
			Name:           "Test dashboard",
			ProjectId:      uuid.New(),
			OrganizationId: orgId,
		}
		err := SaveMetricsDashboard(dashboard)
		require.NoError(t, err)
		_, err = FindMetricsDashboardById(dashboard.ID)
		require.NoError(t, err)

		var afterSaveCount int64
		conn.Model(&MetricsDashboard{}).
			Count(&afterSaveCount)

		assert.Greater(t, afterSaveCount, beforeSaveCount)
	})
}

func TestListMetricsDashboards(t *testing.T) {
	setup()

	t.Run("should list dashboards", func(t *testing.T) {
		dashboards, err := ListMetricsDashboardsByProject(projectId)
		require.NoError(t, err)
		assert.Len(t, dashboards, 3)
	})

	t.Run("should return empty if not found", func(t *testing.T) {
		dashboards, err := ListMetricsDashboardsByProject(uuid.New())
		require.NoError(t, err)
		assert.Len(t, dashboards, 0)
	})
}
