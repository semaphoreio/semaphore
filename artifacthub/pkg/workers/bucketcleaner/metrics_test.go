package bucketcleaner

import (
	"testing"
	"time"

	uuid "github.com/satori/go.uuid"
	privateapi "github.com/semaphoreio/semaphore/artifacthub/pkg/api/private"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/db"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/models"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// The age gauge is the only alert this feature has, so what it counts as
// outstanding has to match what is.
func Test__OldestPurgeAge(t *testing.T) {
	t.Run("an idle fleet reads zero", func(t *testing.T) {
		models.PrepareDatabaseForTests()

		age, err := oldestPurgeAgeSeconds()
		require.NoError(t, err)
		assert.Zero(t, age)
	})

	t.Run("a purge in flight is counted", func(t *testing.T) {
		models.PrepareDatabaseForTests()

		projectID := uuid.NewV4().String()
		artifact, err := models.CreateArtifact(uuid.NewV4().String(), projectID)
		require.NoError(t, err)

		require.NoError(t, privateapi.PurgeArtifactContents(projectID))
		require.NoError(t, db.Conn().Model(&models.Artifact{}).
			Where("id = ?", artifact.ID).
			Update("purge_requested_at", time.Now().Add(-2*time.Hour)).Error)

		age, err := oldestPurgeAgeSeconds()
		require.NoError(t, err)
		assert.InDelta(t, 2*time.Hour.Seconds(), float64(age), 60)
	})

	t.Run("a purge cancelled by a restore is not counted", func(t *testing.T) {
		models.PrepareDatabaseForTests()

		projectID := uuid.NewV4().String()
		artifact, err := models.CreateArtifact(uuid.NewV4().String(), projectID)
		require.NoError(t, err)

		require.NoError(t, privateapi.PurgeArtifactContents(projectID))

		// Ten days old, and called off: not outstanding work.
		require.NoError(t, db.Conn().Model(&models.Artifact{}).
			Where("id = ?", artifact.ID).
			Update("purge_requested_at", time.Now().Add(-240*time.Hour)).Error)

		require.NoError(t, privateapi.CancelArtifactPurge(projectID))

		age, err := oldestPurgeAgeSeconds()
		require.NoError(t, err)
		assert.Zero(t, age)
	})

	t.Run("a storage marked for destruction is counted too", func(t *testing.T) {
		models.PrepareDatabaseForTests()

		artifact, err := models.CreateArtifact(uuid.NewV4().String(), uuid.NewV4().String())
		require.NoError(t, err)

		require.NoError(t, db.Conn().Model(&models.Artifact{}).
			Where("id = ?", artifact.ID).
			Update("deleted_at", time.Now().Add(-3*time.Hour)).Error)

		age, err := oldestPurgeAgeSeconds()
		require.NoError(t, err)
		assert.InDelta(t, 3*time.Hour.Seconds(), float64(age), 60)
	})
}
