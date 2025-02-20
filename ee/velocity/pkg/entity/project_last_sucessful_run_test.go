package entity

import (
	"fmt"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/semaphoreio/semaphore/velocity/pkg/database"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestSaveLastSuccessfulRun(t *testing.T) {
	database.Truncate(ProjectLastSuccessfulRun{}.TableName())
	conn := database.Conn()
	now := time.Now().UTC()
	pid := uuid.New()
	oid := uuid.New()
	p := ProjectLastSuccessfulRun{
		ProjectId:           pid,
		OrganizationId:      oid,
		PipelineFileName:    ".semaphore/semaphore.yml",
		BranchName:          "main",
		LastSuccessfulRunAt: now,
		InsertedAt:          now,
		UpdatedAt:           now,
	}

	err := SaveLastSuccessfulRun(&p)
	require.NoError(t, err)
	assert.Equal(t, pid, p.ProjectId)
	assert.Equal(t, oid, p.OrganizationId)
	assert.Equal(t, ".semaphore/semaphore.yml", p.PipelineFileName)
	assert.Equal(t, "main", p.BranchName)
	assert.WithinDuration(t, now, p.LastSuccessfulRunAt, time.Second)

	p2, err := FindLastSuccessfulRun(conn, pid, ".semaphore/semaphore.yml", "main")
	require.NoError(t, err)
	assert.Equal(t, pid, p2.ProjectId)
	assert.Equal(t, oid, p2.OrganizationId)
	assert.WithinDuration(t, now, p2.LastSuccessfulRunAt, time.Second)

	updatedLastRun := time.Now().Add(time.Hour)
	p.LastSuccessfulRunAt = updatedLastRun
	err = SaveLastSuccessfulRun(&p)
	require.NoError(t, err)
	assert.WithinDuration(t, updatedLastRun, p.LastSuccessfulRunAt, time.Second)
}

func TestFindLastSuccessfulRun(t *testing.T) {
	database.Truncate(ProjectLastSuccessfulRun{}.TableName())
	conn := database.Conn()
	now := time.Now().UTC()
	pid := uuid.New()
	oid := uuid.New()
	p := ProjectLastSuccessfulRun{
		ProjectId:           pid,
		OrganizationId:      oid,
		PipelineFileName:    ".semaphore/semaphore.yml",
		BranchName:          "main",
		LastSuccessfulRunAt: now,
		InsertedAt:          now,
		UpdatedAt:           now,
	}

	err := SaveLastSuccessfulRun(&p)
	require.NoError(t, err)

	p2, err := FindLastSuccessfulRun(conn, p.ProjectId, p.PipelineFileName, p.BranchName)
	require.NoError(t, err)
	assert.Equal(t, pid, p2.ProjectId)
	assert.Equal(t, oid, p2.OrganizationId)
	assert.Equal(t, p.PipelineFileName, p2.PipelineFileName)
	assert.Equal(t, p.BranchName, p2.BranchName)
	assert.WithinDuration(t, p.LastSuccessfulRunAt, p2.LastSuccessfulRunAt, time.Second)
	assert.WithinDuration(t, p.InsertedAt, p2.InsertedAt, time.Second)
	assert.WithinDuration(t, p.UpdatedAt, p2.UpdatedAt, time.Second)

}

func TestFindLastSuccessfulRunForAllBranches(t *testing.T) {
	database.Truncate(ProjectLastSuccessfulRun{}.TableName())
	now := time.Now().UTC()
	pid := uuid.New()
	oid := uuid.New()
	p := ProjectLastSuccessfulRun{
		ProjectId:           pid,
		OrganizationId:      oid,
		PipelineFileName:    ".semaphore/semaphore.yml",
		BranchName:          "main",
		LastSuccessfulRunAt: now,
		InsertedAt:          now,
		UpdatedAt:           now,
	}

	err := SaveLastSuccessfulRun(&p)
	require.NoError(t, err)
	p2 := ProjectLastSuccessfulRun{
		ProjectId:           pid,
		OrganizationId:      oid,
		PipelineFileName:    ".semaphore/semaphore.yml",
		BranchName:          "master",
		LastSuccessfulRunAt: now.Add(-1 * time.Hour),
		InsertedAt:          now,
		UpdatedAt:           now,
	}

	err = SaveLastSuccessfulRun(&p2)
	require.NoError(t, err)

	returned, err := FindLastSuccessfulRunForAllBranches(pid, p.PipelineFileName)
	require.NoError(t, err)

	assert.WithinDuration(t, returned.LastSuccessfulRunAt, p.LastSuccessfulRunAt, time.Second)
}

func TestFindLastSuccessfulRuns(t *testing.T) {
	database.Truncate(ProjectLastSuccessfulRun{}.TableName())
	runs := make([]ProjectLastSuccessfulRun, 0)
	now := time.Now().UTC()
	pids := make([]uuid.UUID, 30)

	for i := 0; i < 30; i++ {
		pid := uuid.New()
		pids = append(pids, pid)
		runs = append(runs, createDummyProjectLastSuccessfulRun(now, pid))
	}
	for i := 0; i < 30; i++ {
		runs = append(runs, createDummyProjectLastSuccessfulRun(now.AddDate(0, 0, -1), runs[i].ProjectId))
	}

	for _, run := range runs {
		err := SaveLastSuccessfulRun(&run)
		require.NoError(t, err)
	}

	var c int64
	err := database.Conn().Model(&ProjectLastSuccessfulRun{}).Count(&c).Error
	require.NoError(t, err)
	err = database.Conn().Model(&ProjectLastSuccessfulRun{}).Count(&c).Error
	require.NoError(t, err)
	require.Len(t, runs, 60)
	require.Equal(t, int64(60), c)

	returned, err := FindLastSuccessfulRuns(pids)
	require.NoError(t, err)
	require.Len(t, returned, 30)
	for _, result := range returned {
		assert.WithinDuration(t, result.LastSuccessfulRunAt, now, time.Second)
	}
}

func createDummyProjectLastSuccessfulRun(lastSuccessfulRunAt time.Time, projId uuid.UUID) ProjectLastSuccessfulRun {
	return ProjectLastSuccessfulRun{
		ProjectId:           projId,
		OrganizationId:      uuid.New(),
		PipelineFileName:    fmt.Sprintf("semaphore-%d.yml", lastSuccessfulRunAt.Day()),
		BranchName:          "main",
		LastSuccessfulRunAt: lastSuccessfulRunAt,
		InsertedAt:          time.Now(),
		UpdatedAt:           time.Now(),
	}
}

func TestDeleteProjectLastSuccessfulRunOlderThanOneYear(t *testing.T) {
	database.Truncate(ProjectLastSuccessfulRun{}.TableName())
	conn := database.Conn()

	// Create a project last successful run that is older than one year
	// and one that is not.
	olderThanAYear := time.Now().AddDate(-1, 0, -1)
	olderThanAYearProjectLastSuccessfulRun := createDummyProjectLastSuccessfulRun(olderThanAYear, uuid.New())
	err := SaveLastSuccessfulRun(&olderThanAYearProjectLastSuccessfulRun)
	require.NoError(t, err)

	notOlderThanAYear := time.Now().AddDate(0, 0, -1)
	notOlderThanAYearProjectLastSuccessfulRun := createDummyProjectLastSuccessfulRun(notOlderThanAYear, uuid.New())
	err = SaveLastSuccessfulRun(&notOlderThanAYearProjectLastSuccessfulRun)
	require.NoError(t, err)

	var beforeDeleteCount int64
	err = conn.Model(&ProjectLastSuccessfulRun{}).Count(&beforeDeleteCount).Error
	require.NoError(t, err)
	assert.Equal(t, int64(2), beforeDeleteCount)

	rowsAffected, err := DeleteProjectLastSuccessfulRunOlderThanOneYear()
	require.NoError(t, err)
	assert.Equal(t, int64(1), rowsAffected.Int64)

	var afterDeleteCount int64
	err = conn.Model(&ProjectLastSuccessfulRun{}).Count(&afterDeleteCount).Error
	require.NoError(t, err)
	assert.Equal(t, int64(1), afterDeleteCount)
}
