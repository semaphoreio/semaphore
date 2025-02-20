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

func Test_velocityService_DescribeProjectSettings(t *testing.T) {
	projectId := uuid.NewString()
	service := velocityService{}
	database.Truncate(entity.ProjectSettings{}.TableName())

	t.Run("return empty response when no settings", func(t *testing.T) {
		request := &pb.DescribeProjectSettingsRequest{ProjectId: projectId}

		v, err := service.DescribeProjectSettings(context.Background(), request)
		assert.Nil(t, err)
		assert.NotNil(t, v)
		assert.Equal(t, &pb.DescribeProjectSettingsResponse{Settings: &pb.Settings{}}, v)
	})

	t.Run("return settings successfully", func(t *testing.T) {
		ps := &entity.ProjectSettings{
			ProjectId:          uuid.MustParse(projectId),
			CiBranchName:       "master",
			CiPipelineFileName: ".semaphore/pipeline.yml",
			CdBranchName:       "master",
			CdPipelineFileName: ".semaphore/deployment.yml",
		}

		err := database.Conn().Create(&ps).Error
		assert.NoError(t, err)
		request := &pb.DescribeProjectSettingsRequest{ProjectId: projectId}
		projectSettings, err := service.DescribeProjectSettings(context.Background(), request)
		assert.NotNil(t, projectSettings)
		assert.NoError(t, err)
		protoSettings := ps.ToProto()
		assert.Equal(t, protoSettings.CdBranchName, projectSettings.Settings.CdBranchName)
		assert.Equal(t, protoSettings.CdPipelineFileName, projectSettings.Settings.CdPipelineFileName)
		assert.Equal(t, protoSettings.CiBranchName, projectSettings.Settings.CiBranchName)
		assert.Equal(t, protoSettings.CiPipelineFileName, projectSettings.Settings.CiPipelineFileName)
	})

}
