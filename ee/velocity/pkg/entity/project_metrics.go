package entity

import (
	"database/sql"
	"database/sql/driver"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"gorm.io/gorm"

	"github.com/google/uuid"
	"github.com/semaphoreio/semaphore/velocity/pkg/database"
)

type ProjectMetrics struct {
	ProjectId        uuid.UUID
	PipelineFileName string
	BranchName       string
	CollectedAt      time.Time
	OrganizationId   uuid.UUID
	Metrics          Metrics
}

func (ProjectMetrics) TableName() string {
	return "project_metrics"
}

type Metrics struct {
	All    MetricPoint
	Passed MetricPoint
	Failed MetricPoint
}

type MetricPoint struct {
	Frequency   Frequency
	Performance Performance
	Reliability Reliability
}

type Performance struct {
	StdDev int32
	Avg    int32
	Median int32
	Max    int32
	Min    int32
	P95    int32
}

type Frequency struct {
	Count int32
}

type Reliability struct {
	Total   int32
	Stopped int32
	Failed  int32
	Passed  int32
}

func ProjectMetricsExists(key ProjectMetricsKey) (bool, error) {
	query := database.Conn()
	var count = int64(0)
	query = query.Model(&ProjectMetrics{}).
		Where("project_id = ?", key.ProjectId).
		Where("pipeline_file_name = ?", key.FileName).
		Where("DATE_TRUNC('day', collected_at) = ?", key.CollectedAt.Format("2006-01-02")).
		Where("branch_name = ?", key.BranchName)

	err := query.Count(&count).Error
	if err != nil {
		return false, err
	}

	return count > 0, nil
}

func SaveProjectMetrics(metrics *ProjectMetrics) error {
	tx := database.Conn()
	return SaveProjectMetricsTx(tx, metrics)
}

func SaveProjectMetricsTx(tx *gorm.DB, metrics *ProjectMetrics) error {
	err := tx.Create(metrics).Error
	if err != nil {
		if strings.Contains(err.Error(), "duplicate key value violates unique constraint") {
			return fmt.Errorf("cannot save the same project metric twice")
		}

		return err
	}

	return nil
}

func DeleteProjectMetricsByKey(tx *gorm.DB, key ProjectMetricsKey) error {
	return tx.
		Where("project_id = ? AND pipeline_file_name = ? AND DATE_TRUNC('day', collected_at) = ? AND branch_name = ?",
			key.ProjectId, key.FileName, key.CollectedAt.Format("2006-01-02"), key.BranchName).
		Delete(&ProjectMetrics{}).Error
}

type ProjectMetricsKey struct {
	ProjectId   uuid.UUID
	FileName    string
	BranchName  string
	CollectedAt time.Time
}

func DeleteByOrganizationId(organizationId uuid.UUID) error {
	query := database.Conn()
	return query.
		Where("organization_id = ?", organizationId).
		Delete(&ProjectMetrics{}).Error
}

func ListPipelineFiles(projectID uuid.UUID) (results []string, err error) {
	query := database.Conn().
		Model(&ProjectMetrics{}).
		Select("pipeline_file_name").
		Where("project_id = ?", projectID).
		Group("pipeline_file_name").
		Order(`pipeline_file_name asc`).
		Find(&results)

	if err = query.Error; err != nil {
		return []string{}, err
	}

	return results, nil
}

func (m *Metrics) Value() (driver.Value, error) {
	return json.Marshal(m)
}

func (m *Metrics) Scan(value interface{}) error {
	b, ok := value.([]byte)
	if !ok {
		return errors.New("type assertion to []byte failed")
	}

	return json.Unmarshal(b, m)
}

type ProjectMetricsFilter struct {
	BeginDate        sql.NullTime
	EndDate          sql.NullTime
	ProjectId        uuid.UUID
	PipelineFileName string
	BranchName       string
}

func ListProjectMetricsBy(filter ProjectMetricsFilter) ([]ProjectMetrics, error) {
	var results []ProjectMetrics

	query := database.Conn().Model(&ProjectMetrics{})

	query = query.Where("project_id = ?", filter.ProjectId)
	if len(filter.PipelineFileName) > 0 {
		query = query.Where("pipeline_file_name = ?", filter.PipelineFileName)
	}

	query = query.Where("branch_name = ?", filter.BranchName)

	if filter.BeginDate.Valid {
		query = query.Where("date_trunc('day', collected_at) >= date_trunc('day', ?::timestamp)", filter.BeginDate.Time)
	}

	if filter.EndDate.Valid {
		query = query.Where("date_trunc('day', collected_at) <= date_trunc('day', ?::timestamp)", filter.EndDate.Time)
	}

	err := query.Find(&results).Error

	return results, err
}

func DeleteProjectMetricsOlderThanSixMonths() (sql.NullInt64, error) {
	query := database.Conn()
	result := query.
		Where("collected_at < now() - interval '6 month'").
		Delete(&ProjectMetrics{})

	if result.Error != nil {
		return sql.NullInt64{}, result.Error
	}

	return sql.NullInt64{
		Int64: result.RowsAffected,
		Valid: true,
	}, nil
}

func SelectOrganizationIDsWithMetricsWithinLast30Days() ([]uuid.UUID, error) {
	query := database.Conn()
	var results []uuid.UUID

	err := query.
		Model(&ProjectMetrics{}).
		Where("DATE_TRUNC('day', collected_at) >= DATE_TRUNC('day', now() - interval '30 days')").
		Select("organization_id").
		Distinct().
		Find(&results).Error

	return results, err
}

type ListProjectMetricsWithinFilter struct {
	OrganizationId uuid.UUID
	ProjectIDs     []uuid.UUID
}

func ListProjectMetricsWithinLast30Days(f ListProjectMetricsWithinFilter) ([]ProjectMetrics, error) {
	query := database.Conn()
	var results []ProjectMetrics

	query = query.
		Model(&ProjectMetrics{}).
		Where("branch_name = ''").
		Where("collected_at >= (CURRENT_DATE - INTERVAL '30 days') AND collected_at < CURRENT_DATE")

	if f.OrganizationId != uuid.Nil {
		query = query.Where("organization_id = ?", f.OrganizationId)
	}

	if len(f.ProjectIDs) > 0 {
		query = query.Where("project_id IN (?)", f.ProjectIDs)
	}

	err := query.Find(&results).Error

	return results, err
}

type ListFilter struct {
	ProjectIDs []uuid.UUID
	BeginDate  time.Time
	EndDate    time.Time
}

func ListProjectMetrics(f ListFilter) ([]ProjectMetrics, error) {
	query := database.Conn()
	var results []ProjectMetrics

	query = query.
		Model(&ProjectMetrics{}).
		Where("collected_at >= ? AND collected_at <= ?", f.BeginDate, f.EndDate)

	if len(f.ProjectIDs) > 0 {
		query = query.Where("project_id IN (?)", f.ProjectIDs)
	}

	err := query.Find(&results).Error

	return results, err
}
