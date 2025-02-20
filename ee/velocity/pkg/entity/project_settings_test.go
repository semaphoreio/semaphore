package entity

import (
	"fmt"
	"testing"

	"github.com/google/uuid"
	"github.com/semaphoreio/semaphore/velocity/pkg/database"
	"github.com/stretchr/testify/assert"
)

func TestListProjectSettings(t *testing.T) {
	database.Truncate(ProjectSettings{}.TableName())

	createProjectSettings(10, uuid.New())

	branchList := []string{"branch-0", "branch-1", "branch-2", "branch-3", "branch-4",
		"branch-5", "branch-6", "branch-7", "branch-8", "branch-9",
	}
	pipelineList := []string{"pipeline-0", "pipeline-1", "pipeline-2", "pipeline-3",
		"pipeline-4", "pipeline-5", "pipeline-6", "pipeline-7", "pipeline-8", "pipeline-9",
	}
	result, err := ListProjectSettings()
	assert.NoError(t, err)
	assert.NotNil(t, result)
	assert.Len(t, result, 10)
	for _, ps := range result {
		assert.Contains(t, branchList, ps.CdBranchName)
		assert.Contains(t, pipelineList, ps.CdPipelineFileName)
	}
}

func TestDeleteProjectSettingsByOrgId(t *testing.T) {
	database.Truncate(ProjectSettings{}.TableName())

	createProjectSettings(5, uuid.New())
	createProjectSettings(5, orgId)

	var before, after int64
	database.Conn().Model(&ProjectSettings{}).Count(&before)

	err := DeleteProjectSettingsByOrgId(orgId.String())
	assert.NoError(t, err)
	database.Conn().Model(&ProjectSettings{}).Count(&after)

	assert.Equal(t, before-5, after)
}

func createProjectSettings(size int, orgId uuid.UUID) {
	for i := 0; i < size; i++ {
		ps := ProjectSettings{
			ProjectId:          uuid.New(),
			CdBranchName:       fmt.Sprintf("branch-%d", i),
			CdPipelineFileName: fmt.Sprintf("pipeline-%d", i),
			OrganizationId:     orgId,
		}

		if err := database.Conn().Create(&ps).Error; err != nil {
			panic(err)
		}
	}

}
