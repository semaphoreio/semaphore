package collector

import (
	"database/sql"
	"log"

	"github.com/google/uuid"
	"github.com/semaphoreio/semaphore/velocity/pkg/entity"
	"github.com/semaphoreio/semaphore/velocity/pkg/service"
	"gorm.io/gorm"
)

type mttrId struct {
	projectId        uuid.UUID
	pipelineFileName string
	branchName       string
}

type Mttr struct {
	ID                mttrId
	db                *gorm.DB
	projectHubService service.ProjectHubClient
}

func NewMttr(db *gorm.DB, phService service.ProjectHubClient, projectId uuid.UUID, pipelineFileName string, branchName string) Mttr {
	return Mttr{
		ID:                mttrId{projectId, pipelineFileName, branchName},
		db:                db,
		projectHubService: phService,
	}
}

func (mttr *Mttr) CheckWithPipeline(pipelineRun entity.PipelineRun) error {
	projectMttr := mttr.findRecord()

	if projectMttr.Id == uuid.Nil {
		return mttr.createRecord(projectMttr, pipelineRun)
	}
	return mttr.updateRecord(projectMttr, pipelineRun)
}

func (mttr *Mttr) findRecord() *entity.ProjectMTTR {

	projectMttr, err := entity.FindLastMttr(mttr.db, mttr.ID.projectId, mttr.ID.pipelineFileName, mttr.ID.branchName)
	if err != nil {
		projectMttr = entity.ProjectMTTR{
			ProjectId:        mttr.ID.projectId,
			PipelineFileName: mttr.ID.pipelineFileName,
			BranchName:       mttr.ID.branchName,
		}
	}

	return &projectMttr
}

func (mttr *Mttr) createRecord(projectMttr *entity.ProjectMTTR, pipelineRun entity.PipelineRun) error {
	if pipelineRun.State() == entity.PipelineRunResultFailed {
		projectMttr.FailedAt = pipelineRun.DoneAt
		projectMttr.FailedPplId = pipelineRun.PipelineId
		organization, err := service.LookupOrganization(
			service.FindOrganizationInDB(mttr.db, pipelineRun.ProjectId),
			service.FindOrganizationInGrpc(mttr.projectHubService, pipelineRun.ProjectId),
		)

		if err != nil {
			log.Printf("Failed to find organization: %s", err)
			return err
		}

		projectMttr.OrganizationId = organization.Id
		return mttr.db.Create(&projectMttr).Error
	}
	return nil
}

func (mttr *Mttr) updateRecord(projectMttr *entity.ProjectMTTR, pipelineRun entity.PipelineRun) error {
	if pipelineRun.State() == entity.PipelineRunResultPassed {
		projectMttr.PassedAt = sql.NullTime{Time: pipelineRun.DoneAt, Valid: true}
		projectMttr.PassedPplId = &pipelineRun.PipelineId
		return mttr.db.Save(&projectMttr).Error
	}
	return nil
}
