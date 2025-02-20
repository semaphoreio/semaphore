package entity

import (
	"testing"
	"time"

	"github.com/golang/protobuf/ptypes/timestamp"
	"github.com/google/uuid"
	"github.com/semaphoreio/semaphore/velocity/pkg/database"
	pb "github.com/semaphoreio/semaphore/velocity/pkg/protos/plumber.pipeline"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestPipelineRun_Save(t *testing.T) {
	database.Truncate(PipelineRun{}.TableName())
	pipelineId := uuid.New()
	projectId := uuid.New()
	branchId := uuid.New()
	now := time.Now()

	s1 := PipelineRun{
		PipelineId:       pipelineId,
		ProjectId:        projectId,
		BranchId:         branchId,
		BranchName:       "Name",
		PipelineFileName: "semaphore.yml",
		Result:           "PASSED",
		Reason:           "TEST",
		CreatedAt:        now,
		QueueingAt:       now,
		RunningAt:        now,
		DoneAt:           now,
		UpdatedAt:        now,
	}

	s2 := PipelineRun{
		PipelineId:       pipelineId,
		ProjectId:        projectId,
		BranchId:         branchId,
		BranchName:       "Name",
		PipelineFileName: "semaphore.yml",
		Result:           "PASSED",
		Reason:           "TEST",
		CreatedAt:        now,
		QueueingAt:       now,
		RunningAt:        now,
		DoneAt:           now,
		UpdatedAt:        now,
	}

	err := SavePipelineRun(&s1)
	require.Nil(t, err)

	err = SavePipelineRun(&s2)
	assert.NotNil(t, err)
	assert.Equal(t, "pipeline id must be unique", err.Error())
}

func TestPipelineRun_Load(t *testing.T) {
	// arrange
	projectId := uuid.New()
	pplId := uuid.New()
	branchId := uuid.New()
	now := time.Now()

	run := &PipelineRun{
		PipelineId:       pplId,
		ProjectId:        projectId,
		BranchId:         branchId,
		BranchName:       "master",
		PipelineFileName: "semaphore.yml",
		Result:           "PASSED",
		Reason:           "TEST",
		QueueingAt:       now.UTC(),
		RunningAt:        now.UTC(),
		DoneAt:           now.UTC(),
	}
	tNow := timestamp.Timestamp{
		Seconds: now.Unix(),
		Nanos:   int32(now.Nanosecond()),
	}
	pipeline := &pb.Pipeline{
		PplId:        pplId.String(),
		Name:         "Build and Test",
		ProjectId:    projectId.String(),
		BranchName:   "master",
		PendingAt:    &tNow,
		QueuingAt:    &tNow,
		RunningAt:    &tNow,
		StoppingAt:   &tNow,
		DoneAt:       &tNow,
		YamlFileName: "semaphore.yml",
		State:        pb.Pipeline_DONE,
		Result:       pb.Pipeline_PASSED,
		ResultReason: pb.Pipeline_TEST,
		BranchId:     branchId.String(),
	}
	// act
	pr := &PipelineRun{}
	pr.Load(pipeline)

	// assert
	assert.Equal(t, run, pr)
}

func TestListPipelineRuns(t *testing.T) {
	projectId := uuid.New()
	branchId := uuid.New()
	now := time.Now()

	runs, err := ListPipelineRuns(projectId, now, "semaphore.yml", "")
	require.Nil(t, err)
	require.NotNil(t, runs)
	require.Len(t, runs, 0)

	dummyPipelineRun(uuid.New(), projectId, branchId, now)
	dummyPipelineRun(uuid.New(), projectId, branchId, now)
	dummyPipelineRun(uuid.New(), projectId, uuid.New(), now)

	runs, err = ListPipelineRuns(projectId, now, "semaphore.yml", "")
	require.Nil(t, err)
	require.NotNil(t, runs)
	require.Len(t, runs, 3)

}

func dummyPipelineRun(pplId uuid.UUID, projectId uuid.UUID, branchId uuid.UUID, now time.Time) *PipelineRun {
	r := PipelineRun{
		PipelineId:       pplId,
		ProjectId:        projectId,
		BranchId:         branchId,
		BranchName:       "master",
		PipelineFileName: "semaphore.yml",
		Result:           "PASSED",
		Reason:           "TEST",
		QueueingAt:       now.UTC(),
		RunningAt:        now.UTC(),
		DoneAt:           now.UTC(),
	}

	if err := SavePipelineRun(&r); err != nil {
		panic(err)
	}

	return &r
}

func TestDeletePipelineRunsOlderThan31Days(t *testing.T) {
	database.Truncate(PipelineRun{}.TableName())

	for i := 0; i < 100; i++ {
		daysAgo := time.Now().AddDate(0, 0, -i).Add(-time.Second)
		dummyPipelineRun(uuid.New(), uuid.New(), uuid.New(), daysAgo)
	}
	conn := database.Conn()
	var beforeDeleteCount int64
	conn.Model(&PipelineRun{}).
		Count(&beforeDeleteCount)

	rowsAffected, err := DeletePipelineRunsOlderThan31Days()
	assert.Nil(t, err)
	assert.Equal(t, int64(69), rowsAffected.Int64)

	var afterDeleteCount int64
	conn.Model(&PipelineRun{}).
		Count(&afterDeleteCount)

	assert.Equal(t, int64(31), afterDeleteCount)
}
