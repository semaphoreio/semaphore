package bucketcleaner

import (
	"os"
	"testing"
	"time"

	"github.com/semaphoreio/semaphore/artifacthub/pkg/db"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/models"
	"github.com/stretchr/testify/assert"
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

	t.Run("it can mark retention polices as scheduled", func(t *testing.T) {
		ids := []string{policy.ArtifactID.String()}

		scheduler.markBatchAsScheduled(db.Conn(), ids)

		err := policy.Reload()
		assert.Nil(t, err)

		assert.NotNil(t, policy.ScheduledForCleaningAt)
	})
}
