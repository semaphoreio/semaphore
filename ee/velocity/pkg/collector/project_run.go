package collector

import (
	"log"

	"github.com/google/uuid"
	"github.com/semaphoreio/semaphore/velocity/pkg/entity"
	"github.com/semaphoreio/semaphore/velocity/pkg/service"
	"gorm.io/gorm"
)

type projectRunId struct {
	projectId        uuid.UUID
	pipelineFileName string
	branchName       string
}

type ProjectRun struct {
	ID                projectRunId
	db                *gorm.DB
	projectHubService service.ProjectHubClient
}

func NewProjectRun(db *gorm.DB, phService service.ProjectHubClient, projectId uuid.UUID, pipelineFileName string, branchName string) ProjectRun {
	return ProjectRun{
		ID:                projectRunId{projectId, pipelineFileName, branchName},
		db:                db,
		projectHubService: phService,
	}
}

func (pr *ProjectRun) findRecord() *entity.ProjectLastSuccessfulRun {
	lastRun, err := entity.FindLastSuccessfulRun(pr.db, pr.ID.projectId, pr.ID.pipelineFileName, pr.ID.branchName)
	if err != nil {
		lastRun = &entity.ProjectLastSuccessfulRun{
			ProjectId:        pr.ID.projectId,
			PipelineFileName: pr.ID.pipelineFileName,
			BranchName:       pr.ID.branchName,
		}
	}

	return lastRun
}

func (pr *ProjectRun) CheckWithPipeline(pipelineRun entity.PipelineRun) error {
	lastRun := pr.findRecord()

	if lastRun.Id == uuid.Nil {
		return pr.createRecord(lastRun, pipelineRun)
	}

	return pr.updateRecord(lastRun, pipelineRun)
}

func (pr *ProjectRun) createRecord(lastRun *entity.ProjectLastSuccessfulRun, pipelineRun entity.PipelineRun) error {
	if pipelineRun.State() == entity.PipelineRunResultPassed {
		lastRun.LastSuccessfulRunAt = pipelineRun.DoneAt
		organization, err := service.LookupOrganization(
			service.FindOrganizationInDB(pr.db, pipelineRun.ProjectId),
			service.FindOrganizationInGrpc(pr.projectHubService, pipelineRun.ProjectId),
		)

		if err != nil {
			log.Printf("Failed to find organization: %s", err)
			return err
		}

		lastRun.OrganizationId = organization.Id
		return pr.db.Create(&lastRun).Error
	}
	return nil
}

func (pr *ProjectRun) updateRecord(lastRun *entity.ProjectLastSuccessfulRun, pipelineRun entity.PipelineRun) error {
	if pipelineRun.State() == entity.PipelineRunResultPassed {
		lastRun.LastSuccessfulRunAt = pipelineRun.DoneAt
		return pr.db.Save(&lastRun).Error
	}
	return nil
}
