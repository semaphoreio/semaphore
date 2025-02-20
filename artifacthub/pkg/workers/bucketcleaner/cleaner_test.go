package bucketcleaner

import (
	"context"
	"testing"
	"time"

	uuid "github.com/satori/go.uuid"
	privateapi "github.com/semaphoreio/semaphore/artifacthub/pkg/api/private"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/db"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/models"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/storage"
	"github.com/stretchr/testify/assert"
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

func refreshPolicyCleanedAt(artifactID uuid.UUID) error {
	r, err := models.FindRetentionPolicy(artifactID)
	if err != nil {
		return err
	}

	now := time.Now().Add(-48 * time.Hour)
	r.LastCleanedAt = &now
	return db.Conn().Save(r).Error
}
