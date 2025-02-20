package api

import (
	"context"
	"testing"

	"github.com/google/uuid"
	"github.com/semaphoreio/semaphore/velocity/pkg/database"
	"github.com/semaphoreio/semaphore/velocity/pkg/entity"
	pb "github.com/semaphoreio/semaphore/velocity/pkg/protos/velocity"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestInitializeFlakyTestsFilters(t *testing.T) {
	service := velocityService{}
	projectId := uuid.New()
	organizationId := uuid.New()

	database.Truncate(entity.FlakyTestsFilter{}.TableName())
	query := database.Conn()

	var count int64
	query.Model(&entity.FlakyTestsFilter{}).Count(&count)
	assert.Equal(t, int64(0), count)

	res, err := service.InitializeFlakyTestsFilters(context.Background(), &pb.InitializeFlakyTestsFiltersRequest{
		ProjectId:      projectId.String(),
		OrganizationId: organizationId.String(),
	})
	require.Nil(t, err)

	query.Model(&entity.FlakyTestsFilter{}).Count(&count)
	assert.Equal(t, int64(5), count)

	filters := res.Filters
	assert.Equal(t, 5, len(filters))
	for _, filter := range filters {
		assert.Equal(t, projectId, uuid.MustParse(filter.ProjectId))
		assert.Equal(t, organizationId, uuid.MustParse(filter.OrganizationId))
	}

}
