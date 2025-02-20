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

func Test_velocityService_UpdateProjectSettings(t *testing.T) {
	projectId := uuid.NewString()
	database.Truncate(entity.ProjectSettings{}.TableName())

	service := velocityService{}
	t.Run("throw error when settings is nil", func(t *testing.T) {
		request := &pb.UpdateProjectSettingsRequest{
			ProjectId: projectId,
			Settings:  nil,
		}

		_, err := service.UpdateProjectSettings(context.Background(), request)
		assert.NotNil(t, err)
	})
	t.Run("create settings successfully", func(t *testing.T) {
		request := &pb.UpdateProjectSettingsRequest{
			ProjectId: projectId,
			Settings: &pb.Settings{
				CdBranchName:       "master",
				CdPipelineFileName: ".semaphore/deployment.yml",
			},
		}

		var beforeAction, afterAction int64
		database.Conn().Model(entity.ProjectSettings{}).Count(&beforeAction)

		response, err := service.UpdateProjectSettings(context.Background(), request)
		assert.NoError(t, err)
		assert.NotNil(t, response)
		assert.Equal(t, request.Settings, response.Settings)
		database.Conn().Model(entity.ProjectSettings{}).Count(&afterAction)
		assert.Less(t, beforeAction, afterAction)
	})

	t.Run("update project settings", func(t *testing.T) {
		request := &pb.UpdateProjectSettingsRequest{
			ProjectId: projectId,
			Settings: &pb.Settings{
				CdBranchName:       "main",
				CdPipelineFileName: ".semaphore/deploy.yml",
			},
		}

		var beforeAction, afterAction int64
		database.Conn().Model(entity.ProjectSettings{}).Count(&beforeAction)

		response, err := service.UpdateProjectSettings(context.Background(), request)
		assert.NoError(t, err)
		assert.NotNil(t, response)
		assert.Equal(t, request.Settings, response.Settings)
		database.Conn().Model(entity.ProjectSettings{}).Count(&afterAction)
		assert.Equal(t, beforeAction, afterAction)
	})

	t.Run("update project settings with empty values", func(t *testing.T) {
		request := &pb.UpdateProjectSettingsRequest{
			ProjectId: projectId,
			Settings: &pb.Settings{
				CdBranchName:       "",
				CdPipelineFileName: "",
			},
		}

		var beforeAction, afterAction int64
		database.Conn().Model(entity.ProjectSettings{}).Count(&beforeAction)

		response, err := service.UpdateProjectSettings(context.Background(), request)
		assert.NoError(t, err)
		assert.NotNil(t, response)
		assert.Equal(t, request.Settings, response.Settings)
		database.Conn().Model(entity.ProjectSettings{}).Count(&afterAction)
		assert.Equal(t, beforeAction, afterAction)
	})

	t.Run("update project settings with values and ci settings", func(t *testing.T) {
		request := &pb.UpdateProjectSettingsRequest{
			ProjectId: projectId,
			Settings: &pb.Settings{
				CiBranchName:       "main",
				CiPipelineFileName: ".semaphore/ci.yml",
				CdBranchName:       "main",
				CdPipelineFileName: ".semaphore/deploy.yml",
			},
		}

		var beforeAction, afterAction int64
		database.Conn().Model(entity.ProjectSettings{}).Count(&beforeAction)

		response, err := service.UpdateProjectSettings(context.Background(), request)
		assert.NoError(t, err)
		assert.NotNil(t, response)
		assert.Equal(t, request.Settings, response.Settings)
		database.Conn().Model(entity.ProjectSettings{}).Count(&afterAction)
		assert.Equal(t, beforeAction, afterAction)
	})

	t.Run("update project settings with empty values for CI settings", func(t *testing.T) {
		request := &pb.UpdateProjectSettingsRequest{
			ProjectId: projectId,
			Settings: &pb.Settings{
				CiBranchName:       "",
				CiPipelineFileName: "",
				CdBranchName:       "main",
				CdPipelineFileName: ".semaphore/deploy.yml",
			},
		}

		var beforeAction, afterAction int64
		database.Conn().Model(entity.ProjectSettings{}).Count(&beforeAction)

		response, err := service.UpdateProjectSettings(context.Background(), request)
		assert.NoError(t, err)
		assert.NotNil(t, response)
		assert.Equal(t, request.Settings, response.Settings)
		assert.Len(t, response.Settings.CiBranchName, 0)
		assert.Len(t, response.Settings.CiPipelineFileName, 0)
		database.Conn().Model(entity.ProjectSettings{}).Count(&afterAction)
		assert.Equal(t, beforeAction, afterAction)
	})

	t.Run("update project settings with empty values for CD settings", func(t *testing.T) {
		request := &pb.UpdateProjectSettingsRequest{
			ProjectId: projectId,
			Settings: &pb.Settings{
				CiBranchName:       "main",
				CiPipelineFileName: ".semaphore/ci.yml",
				CdBranchName:       "",
				CdPipelineFileName: "",
			},
		}

		var beforeAction, afterAction int64
		database.Conn().Model(entity.ProjectSettings{}).Count(&beforeAction)

		response, err := service.UpdateProjectSettings(context.Background(), request)
		assert.NoError(t, err)
		assert.NotNil(t, response)
		assert.Equal(t, request.Settings, response.Settings)
		assert.Len(t, response.Settings.CdBranchName, 0)
		assert.Len(t, response.Settings.CdPipelineFileName, 0)
		database.Conn().Model(entity.ProjectSettings{}).Count(&afterAction)
		assert.Equal(t, beforeAction, afterAction)
	})

	t.Run("update project settings with empty values for CI and CD settings", func(t *testing.T) {
		request := &pb.UpdateProjectSettingsRequest{
			ProjectId: projectId,
			Settings: &pb.Settings{
				CiBranchName:       "",
				CiPipelineFileName: "",
				CdBranchName:       "",
				CdPipelineFileName: "",
			},
		}

		var beforeAction, afterAction int64
		database.Conn().Model(entity.ProjectSettings{}).Count(&beforeAction)

		response, err := service.UpdateProjectSettings(context.Background(), request)
		assert.NoError(t, err)
		assert.NotNil(t, response)
		assert.Equal(t, request.Settings, response.Settings)
		assert.Len(t, response.Settings.CiBranchName, 0)
		assert.Len(t, response.Settings.CiPipelineFileName, 0)
		assert.Len(t, response.Settings.CdBranchName, 0)
		assert.Len(t, response.Settings.CdPipelineFileName, 0)
		database.Conn().Model(entity.ProjectSettings{}).Count(&afterAction)
		assert.Equal(t, beforeAction, afterAction)
	})
}
