package entity

import (
	"database/sql"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/semaphoreio/semaphore/velocity/pkg/database"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func createDummyProjectMTTR(failedAt time.Time) ProjectMTTR {
	return ProjectMTTR{
		ProjectId:        uuid.New(),
		OrganizationId:   uuid.New(),
		PipelineFileName: "semaphore.yml",
		BranchName:       "",
		FailedPplId:      uuid.New(),
		FailedAt:         failedAt,
		PassedPplId:      nil,
		PassedAt:         sql.NullTime{},
	}
}

func TestDeleteProjectMTTROlderThanOneYear(t *testing.T) {
	database.Truncate(ProjectMTTR{}.TableName())
	conn := database.Conn()

	olderThanAYear := time.Now().AddDate(-1, 0, -1)
	olderThanAYearProjectMTTR := createDummyProjectMTTR(olderThanAYear)
	err := conn.Create(&olderThanAYearProjectMTTR).Error
	require.NoError(t, err)

	notOlderThanAYear := time.Now().AddDate(0, 0, -1)
	notOlderThanAYearProjectMTTR := createDummyProjectMTTR(notOlderThanAYear)
	err = conn.Create(&notOlderThanAYearProjectMTTR).Error
	require.NoError(t, err)

	var beforeDeleteCount int64
	err = conn.Model(&ProjectMTTR{}).Count(&beforeDeleteCount).Error
	require.NoError(t, err)
	assert.Equal(t, int64(2), beforeDeleteCount)

	rowsAffected, err := DeleteProjectMTTROlderThanOneYear()
	require.NoError(t, err)
	require.Equal(t, int64(1), rowsAffected.Int64)

	var afterDeleteCount int64
	err = conn.Model(&ProjectMTTR{}).Count(&afterDeleteCount).Error
	require.NoError(t, err)
	assert.Equal(t, int64(1), afterDeleteCount)
}
