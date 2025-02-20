package entity

import (
	"database/sql"
	"time"

	"github.com/google/uuid"
	"github.com/semaphoreio/semaphore/velocity/pkg/database"
	"gorm.io/gorm"
)

type ProjectLastSuccessfulRun struct {
	Id                  uuid.UUID
	ProjectId           uuid.UUID
	OrganizationId      uuid.UUID
	PipelineFileName    string
	BranchName          string
	LastSuccessfulRunAt time.Time
	InsertedAt          time.Time
	UpdatedAt           time.Time
}

func (r *ProjectLastSuccessfulRun) BeforeCreate(_ *gorm.DB) (err error) {
	r.Id = uuid.New()
	now := time.Now().UTC()
	r.InsertedAt = now
	r.UpdatedAt = now
	return
}

func (r *ProjectLastSuccessfulRun) BeforeUpdate(_ *gorm.DB) (err error) {
	now := time.Now().UTC()
	r.UpdatedAt = now
	return
}

func (ProjectLastSuccessfulRun) TableName() string {
	return "project_last_successful_runs"
}

func SaveLastSuccessfulRun(run *ProjectLastSuccessfulRun) error {
	conn := database.Conn()
	successfulRun, err := FindLastSuccessfulRun(conn, run.ProjectId, run.PipelineFileName, run.BranchName)
	if err != nil {
		// If the run doesn't exist, create it
		return conn.Create(run).Error
	}

	return conn.Table(successfulRun.TableName()).
		Where("id = ?", successfulRun.Id).
		Updates(map[string]interface{}{
			"last_successful_run_at": run.LastSuccessfulRunAt,
			"updated_at":             time.Now(),
		}).Error
}

func FindLastSuccessfulRun(db *gorm.DB, projectId uuid.UUID, pipelineFileName string, branchName string) (*ProjectLastSuccessfulRun, error) {
	projectLastSuccessfulRun := ProjectLastSuccessfulRun{
		ProjectId:        projectId,
		PipelineFileName: pipelineFileName,
		BranchName:       branchName,
	}

	query := db.
		Where("project_id = ?", projectId).
		Where("pipeline_file_name = ?", pipelineFileName)

	if branchName != "" {
		query.
			Where("branch_name = ?", branchName)
	}

	err := query.First(&projectLastSuccessfulRun).Error

	return &projectLastSuccessfulRun, err
}

func FindLastSuccessfulRunForAllBranches(projectId uuid.UUID, pipelineFileName string) (*ProjectLastSuccessfulRun, error) {
	var projectLastSuccessfulRun ProjectLastSuccessfulRun

	query := database.Conn()

	query = query.Where("project_id = ?", projectId)

	if len(pipelineFileName) > 0 {
		query = query.Where("pipeline_file_name = ?", pipelineFileName)
	}

	query = query.
		Order("last_successful_run_at desc").
		Limit(1)

	err := query.Select("last_successful_run_at").Find(&projectLastSuccessfulRun).Error
	return &projectLastSuccessfulRun, err
}

func FindLastSuccessfulRuns(projectIDs []uuid.UUID) ([]ProjectLastSuccessfulRun, error) {
	results := make([]ProjectLastSuccessfulRun, 0)
	query := database.Conn()

	query = query.Model(&ProjectLastSuccessfulRun{}).Select("project_id", "MAX(last_successful_run_at) as last_successful_run_at").
		Where("project_id IN (?)", projectIDs).
		Group("project_id")

	err := query.Debug().Find(&results).Error

	return results, err
}

func DeleteProjectLastSuccessfulRunOlderThanOneYear() (sql.NullInt64, error) {
	result := database.Conn().
		Where("last_successful_run_at < now() - interval '1 year'").
		Delete(&ProjectLastSuccessfulRun{})

	if result.Error != nil {
		return sql.NullInt64{}, result.Error
	}

	return sql.NullInt64{
		Int64: result.RowsAffected,
		Valid: true,
	}, nil
}
