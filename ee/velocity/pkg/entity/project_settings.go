package entity

import (
	"github.com/google/uuid"
	"github.com/semaphoreio/semaphore/velocity/pkg/database"
	pb "github.com/semaphoreio/semaphore/velocity/pkg/protos/velocity"
	"gorm.io/gorm/clause"
)

type ProjectSettings struct {
	ProjectId      uuid.UUID
	OrganizationId uuid.UUID

	CiBranchName       string
	CiPipelineFileName string

	CdBranchName       string
	CdPipelineFileName string
}

func (ProjectSettings) TableName() string {
	return "project_settings"
}

func (p ProjectSettings) ToProto() *pb.Settings {
	return &pb.Settings{
		CiBranchName:       p.CiBranchName,
		CiPipelineFileName: p.CiPipelineFileName,
		CdBranchName:       p.CdBranchName,
		CdPipelineFileName: p.CdPipelineFileName,
	}
}

func FindProjectSettingsByProjectId(id string) (*ProjectSettings, error) {
	result := &ProjectSettings{}

	query := database.Conn()

	return result, query.Where("project_id = ?", id).First(result).Error
}

func ProjectSettingsByProjectIDs(projectIDs []uuid.UUID) ([]*ProjectSettings, error) {
	result := make([]*ProjectSettings, 0)
	query := database.Conn()

	err := query.Where("project_id IN ?", projectIDs).Find(&result).Error

	return result, err
}

func UpdateProjectSettings(projectId string, settings *pb.Settings) (*ProjectSettings, error) {
	query := database.Conn()

	query = query.Clauses(clause.OnConflict{
		Columns:   []clause.Column{{Name: "project_id"}},
		UpdateAll: true,
	})

	newProjectSetting := &ProjectSettings{ProjectId: uuid.MustParse(projectId),
		CiBranchName:       settings.CiBranchName,
		CiPipelineFileName: settings.CiPipelineFileName,
		CdBranchName:       settings.CdBranchName,
		CdPipelineFileName: settings.CdPipelineFileName,
	}

	return newProjectSetting, query.Create(newProjectSetting).Error
}

func (p ProjectSettings) HasCiBranch() bool {
	return len(p.CiBranchName) > 0
}

func (p ProjectSettings) HasCdBranch() bool {
	return len(p.CdBranchName) > 0
}

func (p ProjectSettings) HasCdPipelineFileName() bool {
	return len(p.CdPipelineFileName) > 0
}

func DeleteProjectSettingsByOrgId(organizationId string) error {
	query := database.Conn()
	return query.Where("organization_id = ?", organizationId).Delete(&ProjectSettings{}).Error
}

func ListProjectSettings() ([]ProjectSettings, error) {

	var settings []ProjectSettings

	query := database.Conn()

	err := query.Find(&settings).Error
	if err != nil {
		return []ProjectSettings{}, err
	}

	return settings, nil
}
