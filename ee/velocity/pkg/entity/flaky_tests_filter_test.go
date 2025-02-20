package entity

import (
	"fmt"
	"testing"

	"github.com/google/uuid"
	"github.com/semaphoreio/semaphore/velocity/pkg/database"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestListFlakyTestsFiltersFor(t *testing.T) {
	database.Truncate(FlakyTestsFilter{}.TableName())

	projectId := uuid.New()

	for i := 0; i < 10; i++ {
		filter := &FlakyTestsFilter{
			ProjectID:      projectId,
			OrganizationId: uuid.New(),
			Name:           fmt.Sprintf("test-%d", i),
			Value:          "test",
		}

		err := CreateFlakyTestsFilter(filter)
		assert.NoError(t, err)
	}

	filters, err := ListFlakyTestsFiltersFor(projectId)
	assert.NoError(t, err)

	require.Equal(t, 10, len(filters), "wrong number of items returned")
	for _, filter := range filters {
		assert.Equal(t, projectId, filter.ProjectID, "wrong project id")
		assert.NotEqual(t, uuid.Nil, filter.ID, "missing id")
	}

}

func TestCreateFlakyTestsFilter(t *testing.T) {
	database.Truncate(FlakyTestsFilter{}.TableName())

	var before, after int64
	err := database.Conn().Model(&FlakyTestsFilter{}).Count(&before).Error
	require.NoError(t, err)

	filter := &FlakyTestsFilter{
		ProjectID:      uuid.New(),
		OrganizationId: uuid.New(),
		Name:           "test",
		Value:          "test",
	}

	err = CreateFlakyTestsFilter(filter)
	assert.NoError(t, err)
	assert.NotEmpty(t, filter.InsertedAt, "missing inserted at")
	assert.NotEmpty(t, filter.UpdatedAt, "missing inserted at")
	assert.NotEmpty(t, filter.ID, "missing id")
	assert.NotEmpty(t, filter.ProjectID, "missing project id")
	assert.NotEmpty(t, filter.OrganizationId, "missing organization id")
	assert.NotEmpty(t, filter.Name, "missing name")
	assert.NotEmpty(t, filter.Value, "missing value")

	err = database.Conn().Model(&FlakyTestsFilter{}).Count(&after).Error
	require.NoError(t, err)

	require.Equal(t, before+1, after, "no new items were created")
}

func TestListFlakyTestsFilterSortOrder(t *testing.T) {
	database.Truncate(FlakyTestsFilter{}.TableName())

	projectId := uuid.New()
	orgId := uuid.New()
	filters, err := InitializeFlakyTestsFilters(projectId, orgId)
	require.NoError(t, err)
	require.Len(t, filters, 5)

	f, err := ListFlakyTestsFiltersFor(projectId)
	assert.NoError(t, err)
	require.Len(t, f, 5)
	assert.Equal(t, f[0].Name, "Current 30 days", "wrong name")
	assert.Equal(t, f[0].Value, "@is.resolved:false @date.from:now-30d", "wrong value")
	assert.Equal(t, f[1].Name, "Previous 30 days", "wrong name")
	assert.Equal(t, f[1].Value, "@is.resolved:false @date.from:now-60d @date.to:now-30d", "wrong value")
	assert.Equal(t, f[2].Name, "Current 90 days", "wrong name")
	assert.Equal(t, f[2].Value, "@is.resolved:false @date.from:now-90d", "wrong value")
	assert.Equal(t, f[3].Name, "Master branch only", "wrong name")
	assert.Equal(t, f[3].Value, "@is.resolved:false @git.branch:master @date.from:now-60d", "wrong value")
	assert.Equal(t, f[4].Name, "More than 10 disruptions", "wrong name")
	assert.Equal(t, f[4].Value, "@is.resolved:false @date.from:now-90d @metric.disruptions:>10", "wrong value")

}

func TestDeleteFlakyTestsFilter(t *testing.T) {
	database.Truncate(FlakyTestsFilter{}.TableName())

	filter := &FlakyTestsFilter{
		ProjectID:      uuid.New(),
		OrganizationId: uuid.New(),
		Name:           "test",
		Value:          "test",
	}

	err := CreateFlakyTestsFilter(filter)
	assert.NoError(t, err)

	var before, after int64
	err = database.Conn().Model(&FlakyTestsFilter{}).Count(&before).Error
	require.NoError(t, err)

	err = DeleteFlakyTestsFilter(filter.ID)
	assert.NoError(t, err)

	err = database.Conn().Model(&FlakyTestsFilter{}).Count(&after).Error
	require.NoError(t, err)

	require.Equal(t, before-1, after, "no items were deleted")
}

func TestUpdateFlakyTestsFilter(t *testing.T) {
	database.Truncate(FlakyTestsFilter{}.TableName())

	filter := &FlakyTestsFilter{
		ProjectID:      uuid.New(),
		OrganizationId: uuid.New(),
		Name:           "test",
		Value:          "test",
	}

	err := CreateFlakyTestsFilter(filter)
	assert.NoError(t, err)

	filter.Name = "test2"
	filter.Value = "test2"

	err = UpdateFlakyTestsFilter(filter)
	assert.NoError(t, err)

	var filter2 FlakyTestsFilter
	err = database.Conn().Model(filter).First(&filter2).Error
	assert.NoError(t, err)

	assert.Equal(t, filter.Name, filter2.Name, "wrong name")
	assert.Equal(t, filter.Value, filter2.Value, "wrong value")
}
