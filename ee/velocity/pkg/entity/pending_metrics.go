package entity

import (
	"time"

	"github.com/google/uuid"
	"github.com/semaphoreio/semaphore/velocity/pkg/database"
)

type PendingMetric struct {
	ProjectId        uuid.UUID
	PipelineFileName string
	PipelinesCount   int
	DoneAt           time.Time
}

func ListPendingMetrics() (pendingMetrics []PendingMetric, err error) {
	query := database.Conn()
	query.
		Model(&PipelineRun{}).
		Select("project_id, pipeline_file_name, DATE_TRUNC('day', done_at) done_at, count(*) pipelines_count").
		Where("DATE_TRUNC('day', done_at) < DATE_TRUNC('day', NOW())").
		Group("project_id, pipeline_file_name, DATE_TRUNC('day', done_at)").
		Order("DATE_TRUNC('day', done_at) asc").
		Find(&pendingMetrics)

	if err = query.Error; err != nil {
		return nil, err
	}
	return pendingMetrics, nil
}
