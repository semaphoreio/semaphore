package entity

import (
	"database/sql"
	"fmt"
	"path"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/semaphoreio/semaphore/velocity/pkg/database"
	protos "github.com/semaphoreio/semaphore/velocity/pkg/protos/plumber.pipeline"
	"gorm.io/gorm"
)

type PipelineRunState = string

const (
	PipelineRunResultPassed = PipelineRunState("PASSED")
	PipelineRunResultFailed = PipelineRunState("FAILED")
)

type PipelineRun struct {
	PipelineId       uuid.UUID
	ProjectId        uuid.UUID
	BranchId         uuid.UUID
	BranchName       string
	PipelineFileName string
	Result           string
	Reason           string
	QueueingAt       time.Time
	RunningAt        time.Time
	DoneAt           time.Time
	CreatedAt        time.Time
	UpdatedAt        time.Time
}

func (r *PipelineRun) BeforeCreate(_ *gorm.DB) (err error) {
	now := time.Now()
	r.CreatedAt = now
	r.UpdatedAt = now
	return
}

func (r *PipelineRun) BeforeUpdate(_ *gorm.DB) (err error) {
	r.UpdatedAt = time.Now()
	return
}

func (PipelineRun) TableName() string {
	return "pipeline_runs"
}

func (r *PipelineRun) State() PipelineRunState {
	if PipelineRunState(r.Result) == PipelineRunResultPassed {
		return PipelineRunResultPassed
	}

	return PipelineRunResultFailed
}

func ListPipelineRuns(projectId uuid.UUID, day time.Time, fileName, branchName string) ([]PipelineRun, error) {
	result := make([]PipelineRun, 0)

	query := database.Conn()

	query = query.Model(PipelineRun{}).
		Where("project_id = ?", projectId).
		Where("pipeline_file_name = ?", fileName).
		Where("date_trunc('day', done_at) = ?", day.Format("2006-01-02"))

	if len(branchName) > 0 {
		query = query.Where("branch_name = ?", branchName)
	}

	err := query.Find(&result).Error

	return result, err
}

func SavePipelineRun(run *PipelineRun) error {
	query := database.Conn()

	err := query.Create(run).Error
	if err != nil {
		if strings.Contains(err.Error(), "duplicate key value violates unique constraint") {
			return fmt.Errorf("pipeline id must be unique")
		}

		return err
	}

	return nil
}

func DeletePipelineRunsOlderThan31Days() (sql.NullInt64, error) {
	//for clarity, we are not truncating here, but we don't need day precision.
	result := database.Conn().
		Where("done_at < now() - interval '31 days'").
		Delete(&PipelineRun{})

	if result.Error != nil {
		return sql.NullInt64{}, result.Error
	}

	return sql.NullInt64{
		Int64: result.RowsAffected,
		Valid: true,
	}, nil
}

// Load loads the pipeline protobuf into PipelineRun's entity object
// returns an error if failed to parse the protobuf uuids
func (r *PipelineRun) Load(ppl *protos.Pipeline) (err error) {
	r.PipelineId, err = uuid.Parse(ppl.PplId)
	if err != nil {
		return
	}

	r.BranchId, err = uuid.Parse(ppl.BranchId)
	if err != nil {
		return
	}

	r.ProjectId, err = uuid.Parse(ppl.ProjectId)
	if err != nil {
		return
	}

	r.BranchName = ppl.BranchName
	r.PipelineFileName = path.Join(ppl.WorkingDirectory, ppl.YamlFileName)
	r.Result = strings.ToUpper(ppl.Result.String())
	r.Reason = ppl.ResultReason.String()
	r.QueueingAt = ppl.QueuingAt.AsTime()
	r.RunningAt = ppl.RunningAt.AsTime()
	r.DoneAt = ppl.DoneAt.AsTime()

	return nil
}

func CreateDummyPipelineRun(projectID uuid.UUID, pipelineFileName string, doneAt time.Time) (pipelineRun *PipelineRun, err error) {
	now := time.Now()
	pipelineRun = &PipelineRun{
		ProjectId:        projectID,
		BranchName:       uuid.New().String(),
		BranchId:         uuid.New(),
		PipelineId:       uuid.New(),
		PipelineFileName: pipelineFileName,
		DoneAt:           doneAt,
		Result:           "PASSED",
		Reason:           "TEST",
		CreatedAt:        now,
		QueueingAt:       now,
		RunningAt:        now,
		UpdatedAt:        now,
	}

	if err := SavePipelineRun(pipelineRun); err != nil {
		return nil, err
	}

	return
}
