package entity

import (
	"database/sql"
	"time"

	"github.com/semaphoreio/semaphore/velocity/pkg/database"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type ProjectMTTR struct {
	Id               uuid.UUID
	ProjectId        uuid.UUID
	OrganizationId   uuid.UUID
	PipelineFileName string
	BranchName       string
	FailedPplId      uuid.UUID
	FailedAt         time.Time
	PassedPplId      *uuid.UUID
	PassedAt         sql.NullTime
	InsertedAt       time.Time
	UpdatedAt        time.Time
}

func (r *ProjectMTTR) BeforeCreate(_ *gorm.DB) (err error) {
	r.Id = uuid.New()
	now := time.Now().UTC()
	r.InsertedAt = now
	r.UpdatedAt = now
	return
}

func (r *ProjectMTTR) BeforeUpdate(_ *gorm.DB) (err error) {
	now := time.Now().UTC()
	r.UpdatedAt = now
	return
}

func (ProjectMTTR) TableName() string {
	return "project_mttr"
}

func FindLastMttr(db *gorm.DB, projectId uuid.UUID, pipelineFileName string, branchName string) (ProjectMTTR, error) {
	result := ProjectMTTR{
		ProjectId:        projectId,
		PipelineFileName: pipelineFileName,
		BranchName:       branchName,
	}

	err := db.
		Model(&ProjectMTTR{}).
		Where("project_id = ?", projectId).
		Where("pipeline_file_name = ?", pipelineFileName).
		Where("branch_name = ?", branchName).
		Where("passed_ppl_id IS NULL").
		Find(&result).
		Error

	return result, err
}

func AvgMttr(db *gorm.DB, projectId uuid.UUID, pipelineFileName string, branchName string, fromDate time.Time, toDate time.Time) (float64, error) {
	result := 0.0

	query := db.
		Model(&ProjectMTTR{}).
		Where("project_id = ?", projectId).
		Where("pipeline_file_name = ?", pipelineFileName).
		Where("passed_at >= ?", fromDate).
		Where("passed_at <= ?", toDate).
		Select(`
			EXTRACT(
				EPOCH FROM (
					COALESCE(
						AVG(
							COALESCE(passed_at, now()) - failed_at
						),
						make_interval(0)
					)
				)
			)
		`)

	if branchName != "" {
		query = query.
			Where("pipeline_file_name = ?", pipelineFileName)
	}

	err := query.
		Scan(&result).
		Error

	return result, err
}

func DeleteProjectMTTROlderThanOneYear() (sql.NullInt64, error) {
	conn := database.Conn()
	result := conn.
		Where("failed_at < now() - interval '1 year'").
		Delete(&ProjectMTTR{})

	if result.Error != nil {
		return sql.NullInt64{}, result.Error
	}

	return sql.NullInt64{
		Int64: result.RowsAffected,
		Valid: true,
	}, nil
}
