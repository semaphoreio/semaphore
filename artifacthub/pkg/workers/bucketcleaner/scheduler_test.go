package bucketcleaner

import (
	"os"
	"testing"
	"time"

	uuid "github.com/satori/go.uuid"
	privateapi "github.com/semaphoreio/semaphore/artifacthub/pkg/api/private"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/db"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/models"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func Test__Scheduler(t *testing.T) {
	models.PrepareDatabaseForTests()

	scheduler, err := NewScheduler(os.Getenv("AMQP_URL"), 1*time.Second, 3)
	assert.Nil(t, err)

	t.Run("it can boot up and shut down", func(t *testing.T) {
		assert.Equal(t, 0, scheduler.Cycles)

		scheduler.Start()

		assert.Equal(t, true, scheduler.Running)
		assert.Eventually(t, func() bool { return scheduler.Cycles > 1 }, 5*time.Second, 1*time.Second)

		scheduler.Stop()

		assert.Eventually(t, func() bool { return scheduler.Running == false }, 5*time.Second, 1*time.Second)
	})

	scheduler.Start()
	defer scheduler.Stop()
	assert.True(t, scheduler.Running)

	t.Run("it marks publishes with now() timestamp", func(t *testing.T) {
		_, policy := createBucketWithRetentionPolicy(t)

		assert.Nil(t, policy.ScheduledForCleaningAt)

		assert.Eventually(t, func() bool {
			policy.Reload()

			return policy.ScheduledForCleaningAt != nil
		}, 5*time.Second, 1*time.Second)
	})
}

func Test__Scheduler__WorkingWithRetentionPolicies(t *testing.T) {
	models.PrepareDatabaseForTests()

	scheduler, err := NewScheduler(os.Getenv("AMQP_URL"), 1*time.Second, 3)
	assert.Nil(t, err)

	_, policy := createBucketWithRetentionPolicy(t)

	t.Run("it can load in retention policies with NULL scheduled_for_cleaning_at", func(t *testing.T) {
		assert.Nil(t, policy.ScheduledForCleaningAt)

		ids, err := scheduler.loadBatch(db.Conn())
		assert.Nil(t, err)

		assert.Len(t, ids, 1)
		assert.Equal(t, policy.ArtifactID.String(), ids[0])
	})

	t.Run("it can load in retention policies with scheduled_for_cleaning_at older than a day", func(t *testing.T) {
		changeScheduledForCleaningAtTimestamp(t, policy, -48*time.Hour)

		ids, err := scheduler.loadBatch(db.Conn())
		assert.Nil(t, err)

		assert.Len(t, ids, 1)
		assert.Equal(t, policy.ArtifactID.String(), ids[0])
	})

	t.Run("it doesn't load policies that were updated in the last day", func(t *testing.T) {
		changeScheduledForCleaningAtTimestamp(t, policy, -12*time.Hour)

		ids, err := scheduler.loadBatch(db.Conn())
		assert.Nil(t, err)

		assert.Len(t, ids, 0)
	})

	_, policy = createBucketWithRetentionPolicy(t)

	t.Run("it can mark retention policies as scheduled", func(t *testing.T) {
		ids := []string{policy.ArtifactID.String()}

		require.NoError(t, scheduler.markBatchAsScheduled(db.Conn(), ids))

		err := policy.Reload()
		assert.Nil(t, err)

		assert.NotNil(t, policy.ScheduledForCleaningAt)
	})
}

// A purge that has come due must not sit behind the once-a-day pacing, or the
// artifacts would outlive their grace period by up to another day.
func Test__Scheduler__DuePurgesJumpTheDailyPass(t *testing.T) {
	models.PrepareDatabaseForTests()

	withGracePeriod(t, 72*time.Hour)

	scheduler, err := NewScheduler(os.Getenv("AMQP_URL"), 1*time.Second, 3)
	require.NoError(t, err)

	t.Run("a storage still inside its grace period waits its turn like any other", func(t *testing.T) {
		artifact, policy := createBucketWithRetentionPolicy(t)

		require.NoError(t, privateapi.PurgeArtifactContents(artifact.IdempotencyToken))

		// Cleaned an hour ago, so the daily pass is not due either.
		changeScheduledForCleaningAtTimestamp(t, policy, -1*time.Hour)
		require.NoError(t, setPolicyCleanedAt(policy.ArtifactID, time.Now().Add(-1*time.Hour)))

		ids, err := scheduler.loadBatch(db.Conn())
		require.NoError(t, err)
		assert.NotContains(t, ids, policy.ArtifactID.String())
	})

	t.Run("a storage past its grace period is picked up", func(t *testing.T) {
		artifact, policy := createBucketWithRetentionPolicy(t)

		require.NoError(t, privateapi.PurgeArtifactContents(artifact.IdempotencyToken))
		require.NoError(t, agePurgeMark(artifact.ID, 73*time.Hour))

		changeScheduledForCleaningAtTimestamp(t, policy, -2*time.Hour)
		require.NoError(t, setPolicyCleanedAt(policy.ArtifactID, time.Now().Add(-1*time.Hour)))

		ids, err := scheduler.loadBatch(db.Conn())
		require.NoError(t, err)
		assert.Contains(t, ids, policy.ArtifactID.String())
	})

	// The retry interval is also the floor on how long a due purge waits, and
	// oldest_purge_age is alerted on that wait, so it must stay well under an hour.
	t.Run("a due purge just published is not published again on the next tick", func(t *testing.T) {
		artifact, policy := createBucketWithRetentionPolicy(t)

		require.NoError(t, privateapi.PurgeArtifactContents(artifact.IdempotencyToken))
		require.NoError(t, agePurgeMark(artifact.ID, 73*time.Hour))

		// Published seconds ago, so the work is already on its way.
		changeScheduledForCleaningAtTimestamp(t, policy, -5*time.Second)

		ids, err := scheduler.loadBatch(db.Conn())
		require.NoError(t, err)
		assert.NotContains(t, ids, policy.ArtifactID.String())

		// And picked up again once the retry interval is up, rather than waiting a day.
		changeScheduledForCleaningAtTimestamp(t, policy, -11*time.Minute)

		ids, err = scheduler.loadBatch(db.Conn())
		require.NoError(t, err)
		assert.Contains(t, ids, policy.ArtifactID.String())
	})
}

func setPolicyCleanedAt(artifactID uuid.UUID, at time.Time) error {
	return db.Conn().
		Table("retention_policies").
		Where("artifact_id = ?", artifactID.String()).
		Update("last_cleaned_at", at).
		Error
}

func Test__Scheduler__PublishFailures(t *testing.T) {
	models.PrepareDatabaseForTests()

	_, policy := createBucketWithRetentionPolicy(t)

	// A scheduler that cannot reach the broker at all.
	offline, err := NewScheduler("amqp://127.0.0.1:1/nope", 1*time.Second, 3)
	require.NoError(t, err)

	require.NoError(t, offline.scheduleWork())

	// Marking it anyway would put it out of reach for a day, with nothing left to
	// retry it.
	require.NoError(t, policy.Reload())
	assert.Nil(t, policy.ScheduledForCleaningAt)

	ids, err := offline.loadBatch(db.Conn())
	require.NoError(t, err)
	assert.Contains(t, ids, policy.ArtifactID.String())
}
