package bucketcleaner

import (
	"context"
	"errors"
	"testing"
	"time"

	uuid "github.com/satori/go.uuid"
	privateapi "github.com/semaphoreio/semaphore/artifacthub/pkg/api/private"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/db"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/models"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/storage"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"gorm.io/gorm"
)

func Test__Cleaner(t *testing.T) {
	models.PrepareDatabaseForTests()
	s := storage.NewInMemoryStorage()
	id := uuid.NewV4().String()

	t.Run("deletes old files from active bucket", func(t *testing.T) {
		artifact, _ := createBucketWithRetentionPolicy(t)
		bucket := s.GetBucket(storage.BucketOptions{Name: artifact.BucketName}).(*storage.InMemoryBucket)

		request, err := NewCleanRequest(artifact.ID.String())
		assert.Nil(t, err)

		cleaner := NewBatchCleaner(s, request, 10)

		bucket.Add("/projects/"+id+"/docker/b.txt", daysAgo(10))
		bucket.Add("/workflows/"+id+"/test-results/a.txt", daysAgo(10))
		bucket.Add("/workflows/"+id+"/test-results/b.txt", daysAgo(1))
		bucket.Add("/jobs/"+id+"/test-results/a.txt", daysAgo(10))
		bucket.Add("/jobs/"+id+"/test-results/b.txt", daysAgo(1))

		assert.Equal(t, bucket.Size(), 5)
		nextPageToken, err := cleaner.Run(db.Conn())
		assert.NoError(t, err)
		assert.Empty(t, nextPageToken)
		assert.Equal(t, bucket.Size(), 3)
		assert.Equal(t, cleaner.deletedObjectCount, 2)
		assert.Equal(t, cleaner.visitedObjectCount, 5)
		assert.False(t, cleaner.artifactDeleted)
	})

	t.Run("does not delete empty bucket if still active", func(t *testing.T) {
		artifact, _ := createBucketWithRetentionPolicy(t)
		bucket := s.GetBucket(storage.BucketOptions{Name: artifact.BucketName}).(*storage.InMemoryBucket)
		request, err := NewCleanRequest(artifact.ID.String())
		assert.Nil(t, err)

		cleaner := NewBatchCleaner(s, request, 10)
		assert.Equal(t, bucket.Size(), 0)
		nextPageToken, err := cleaner.Run(db.Conn())
		assert.NoError(t, err)
		assert.Empty(t, nextPageToken)
		assert.Equal(t, bucket.Size(), 0)
		assert.Zero(t, cleaner.deletedObjectCount)
		assert.Zero(t, cleaner.visitedObjectCount)
		assert.False(t, cleaner.artifactDeleted)
	})

	t.Run("deletes old files and bucket if artifact was destroyed", func(t *testing.T) {
		artifact, _ := createBucketWithRetentionPolicy(t)
		err := privateapi.DestroyArtifact(context.TODO(), s, artifact.ID.String())
		assert.NoError(t, err)

		bucket := s.GetBucket(storage.BucketOptions{Name: artifact.BucketName}).(*storage.InMemoryBucket)
		request, err := NewCleanRequest(artifact.ID.String())
		assert.Nil(t, err)

		bucket.Add("/projects/"+id+"/docker/b.txt", daysAgo(10))
		bucket.Add("/workflows/"+id+"/test-results/a.txt", daysAgo(10))
		bucket.Add("/workflows/"+id+"/test-results/b.txt", daysAgo(10))
		bucket.Add("/jobs/"+id+"/test-results/a.txt", daysAgo(10))
		bucket.Add("/jobs/"+id+"/test-results/b.txt", daysAgo(10))

		// first cleaner only empties the bucket, without deleting it.
		cleaner := NewBatchCleaner(s, request, 10)
		assert.Equal(t, bucket.Size(), 5)
		nextPageToken, err := cleaner.Run(db.Conn())
		assert.NoError(t, err)
		assert.Empty(t, nextPageToken)
		assert.Equal(t, bucket.Size(), 0)
		assert.Equal(t, cleaner.deletedObjectCount, 5)
		assert.Equal(t, cleaner.visitedObjectCount, 5)
		assert.False(t, cleaner.artifactDeleted)

		// second run deletes the bucket and the artifact record.
		// NOTE: we need to update the last_cleaned_at timestamp to simulate 1 day passing.
		assert.NoError(t, refreshPolicyCleanedAt(artifact.ID))
		cleaner = NewBatchCleaner(s, request, 10)
		nextPageToken, err = cleaner.Run(db.Conn())
		assert.NoError(t, err)
		assert.Empty(t, nextPageToken)
		assert.Zero(t, cleaner.deletedObjectCount)
		assert.Zero(t, cleaner.visitedObjectCount)
		assert.True(t, cleaner.artifactDeleted)
		_, err = models.FindArtifactByID(artifact.ID.String())
		assert.ErrorContains(t, err, gorm.ErrRecordNotFound.Error())
		_, err = models.FindRetentionPolicy(artifact.ID)
		assert.ErrorContains(t, err, gorm.ErrRecordNotFound.Error())
	})
}

func Test__CleanerPurge(t *testing.T) {
	models.PrepareDatabaseForTests()
	s := storage.NewInMemoryStorage()
	id := uuid.NewV4().String()

	t.Run("a purged storage loses everything, whatever the rules say", func(t *testing.T) {
		artifact, _ := createBucketWithRetentionPolicy(t)
		bucket := s.GetBucket(storage.BucketOptions{Name: artifact.BucketName}).(*storage.InMemoryBucket)

		// None of these would be deleted under the policy: the paths do not match
		// its selectors, and the objects are younger than the one day floor that
		// even a matching rule has to clear.
		bucket.Add("/projects/"+id+"/docker/b.txt", daysAgo(0))
		bucket.Add("/workflows/"+id+"/junit/a.txt", daysAgo(0))
		bucket.Add("/jobs/"+id+"/junit/b.txt", daysAgo(0))

		assert.NoError(t, privateapi.PurgeArtifactContents(artifact.IdempotencyToken))

		request, err := NewCleanRequest(artifact.ID.String())
		assert.Nil(t, err)

		cleaner := NewBatchCleaner(s, request, 10)
		nextPageToken, err := cleaner.Run(db.Conn())
		assert.NoError(t, err)
		assert.Empty(t, nextPageToken)
		assert.Equal(t, 0, bucket.Size())
		assert.Equal(t, 3, cleaner.deletedObjectCount)

		// One run: emptied and the mark off, because every delete succeeded. The
		// storage itself survives, so a restored project can push to it.
		stored, err := models.FindArtifactByID(artifact.ID.String())
		assert.NoError(t, err)
		assert.Nil(t, stored.PurgeRequestedAt)
		assert.Nil(t, stored.DeletedAt)
		assert.False(t, cleaner.artifactDeleted)
	})

	t.Run("the mark comes off once the storage is empty", func(t *testing.T) {
		artifact, _ := createBucketWithRetentionPolicy(t)
		assert.NoError(t, privateapi.PurgeArtifactContents(artifact.IdempotencyToken))

		request, err := NewCleanRequest(artifact.ID.String())
		assert.Nil(t, err)

		cleaner := NewBatchCleaner(s, request, 10)
		_, err = cleaner.Run(db.Conn())
		assert.NoError(t, err)
		assert.True(t, cleaner.purgeCompleted)

		stored, err := models.FindArtifactByID(artifact.ID.String())
		assert.NoError(t, err)
		assert.Nil(t, stored.PurgeRequestedAt)

		// And the storage is still there to be pushed to.
		assert.Nil(t, stored.DeletedAt)
	})

	t.Run("a purge is not held back by the once-a-day rule", func(t *testing.T) {
		artifact, policy := createBucketWithRetentionPolicy(t)
		bucket := s.GetBucket(storage.BucketOptions{Name: artifact.BucketName}).(*storage.InMemoryBucket)

		bucket.Add("/jobs/"+id+"/junit/a.txt", daysAgo(10))

		now := time.Now()
		policy.LastCleanedAt = &now
		assert.NoError(t, db.Conn().Save(policy).Error)

		assert.NoError(t, privateapi.PurgeArtifactContents(artifact.IdempotencyToken))

		request, err := NewCleanRequest(artifact.ID.String())
		assert.Nil(t, err)

		cleaner := NewBatchCleaner(s, request, 10)
		_, err = cleaner.Run(db.Conn())
		assert.NoError(t, err)
		assert.Equal(t, 0, bucket.Size())
	})

	t.Run("a purged storage is destroyed when its project is destroyed", func(t *testing.T) {
		artifact, _ := createBucketWithRetentionPolicy(t)
		assert.NoError(t, privateapi.PurgeArtifactContents(artifact.IdempotencyToken))

		request, err := NewCleanRequest(artifact.ID.String())
		assert.Nil(t, err)

		// The purge empties the storage and takes its own mark off.
		cleaner := NewBatchCleaner(s, request, 10)
		_, err = cleaner.Run(db.Conn())
		assert.NoError(t, err)
		assert.True(t, cleaner.purgeCompleted)

		// 30 days later the project is destroyed for good, and the storage goes.
		assert.NoError(t, privateapi.DestroyArtifact(context.TODO(), s, artifact.ID.String()))

		cleaner = NewBatchCleaner(s, request, 10)
		_, err = cleaner.Run(db.Conn())
		assert.NoError(t, err)
		assert.True(t, cleaner.artifactDeleted)

		_, err = models.FindArtifactByID(artifact.ID.String())
		assert.ErrorContains(t, err, gorm.ErrRecordNotFound.Error())
	})
}

func Test__CleanerPurgeFailures(t *testing.T) {
	models.PrepareDatabaseForTests()
	s := storage.NewInMemoryStorage()
	id := uuid.NewV4().String()

	t.Run("a purge whose deletes fail reports the failure and keeps its mark", func(t *testing.T) {
		artifact, _ := createBucketWithRetentionPolicy(t)
		bucket := s.GetBucket(storage.BucketOptions{Name: artifact.BucketName}).(*storage.InMemoryBucket)

		bucket.Add("/jobs/"+id+"/junit/a.txt", daysAgo(10))
		bucket.DeleteObjectsError = errors.New("failed to delete 1 of 1 objects")

		assert.NoError(t, privateapi.PurgeArtifactContents(artifact.IdempotencyToken))

		request, err := NewCleanRequest(artifact.ID.String())
		assert.Nil(t, err)

		cleaner := NewBatchCleaner(s, request, 10)
		_, err = cleaner.Run(db.Conn())

		// The run has to fail. A purge decides it is finished by reaching the end of
		// the pages, so a delete that quietly did not happen would leave the storage
		// recorded as purged while it is still full.
		assert.Error(t, err)

		stored, err := models.FindArtifactByID(artifact.ID.String())
		require.NoError(t, err)
		assert.NotNil(t, stored.PurgeRequestedAt)
		assert.False(t, cleaner.purgeCompleted)
		assert.Equal(t, 1, bucket.Size())

		bucket.DeleteObjectsError = nil
	})

	t.Run("routine retention carries on past a delete it could not make", func(t *testing.T) {
		artifact, _ := createBucketWithRetentionPolicy(t)
		bucket := s.GetBucket(storage.BucketOptions{Name: artifact.BucketName}).(*storage.InMemoryBucket)

		bucket.Add("/jobs/"+id+"/a.txt", daysAgo(10))
		bucket.DeleteObjectsError = errors.New("one object could not be deleted")

		request, err := NewCleanRequest(artifact.ID.String())
		assert.Nil(t, err)

		// One object that cannot be deleted must not stop a bucket being cleaned, so
		// the routine path keeps its long-standing tolerance.
		cleaner := NewBatchCleaner(s, request, 10)
		_, err = cleaner.Run(db.Conn())
		assert.NoError(t, err)

		bucket.DeleteObjectsError = nil
	})

	t.Run("a completed purge clears its mark", func(t *testing.T) {
		artifact, _ := createBucketWithRetentionPolicy(t)
		assert.NoError(t, privateapi.PurgeArtifactContents(artifact.IdempotencyToken))

		request, err := NewCleanRequest(artifact.ID.String())
		assert.Nil(t, err)

		cleaner := NewBatchCleaner(s, request, 10)
		_, err = cleaner.Run(db.Conn())
		assert.NoError(t, err)
		assert.True(t, cleaner.purgeCompleted)

		stored, err := models.FindArtifactByID(artifact.ID.String())
		require.NoError(t, err)
		assert.Nil(t, stored.PurgeRequestedAt)
	})
}

func refreshPolicyCleanedAt(artifactID uuid.UUID) error {
	r, err := models.FindRetentionPolicy(artifactID)
	if err != nil {
		return err
	}

	now := time.Now().Add(-48 * time.Hour)
	r.LastCleanedAt = &now
	return db.Conn().Save(r).Error
}
