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

	t.Run("purges everything and destroys the storage in a single run", func(t *testing.T) {
		artifact, _ := createBucketWithRetentionPolicy(t)
		err := privateapi.DestroyArtifact(context.TODO(), s, artifact.ID.String())
		assert.NoError(t, err)

		bucket := s.GetBucket(storage.BucketOptions{Name: artifact.BucketName}).(*storage.InMemoryBucket)
		request, err := NewCleanRequest(artifact.ID.String())
		assert.Nil(t, err)

		bucket.Add("/projects/"+id+"/docker/b.txt", daysAgo(10))
		bucket.Add("/workflows/"+id+"/test-results/a.txt", daysAgo(10))
		bucket.Add("/jobs/"+id+"/test-results/a.txt", daysAgo(10))
		// Younger than every retention rule, and younger than the minimum
		// retention age: a purge has to take it anyway.
		bucket.Add("/jobs/"+id+"/test-results/fresh.txt", daysAgo(0))

		cleaner := NewBatchCleaner(s, request, 10)
		assert.Equal(t, bucket.Size(), 4)
		nextPageToken, err := cleaner.Run(db.Conn())
		assert.NoError(t, err)
		assert.Empty(t, nextPageToken)

		assert.Equal(t, bucket.Size(), 0)
		assert.Equal(t, cleaner.deletedObjectCount, 4)
		assert.Equal(t, cleaner.visitedObjectCount, 4)
		assert.True(t, cleaner.artifactDeleted)

		_, err = models.FindArtifactByID(artifact.ID.String())
		assert.ErrorContains(t, err, gorm.ErrRecordNotFound.Error())
		_, err = models.FindRetentionPolicy(artifact.ID)
		assert.ErrorContains(t, err, gorm.ErrRecordNotFound.Error())
	})

	t.Run("purges even when the bucket was already cleaned today", func(t *testing.T) {
		artifact, policy := createBucketWithRetentionPolicy(t)

		now := time.Now()
		policy.LastCleanedAt = &now
		assert.NoError(t, db.Conn().Save(policy).Error)

		assert.NoError(t, privateapi.DestroyArtifact(context.TODO(), s, artifact.ID.String()))

		bucket := s.GetBucket(storage.BucketOptions{Name: artifact.BucketName}).(*storage.InMemoryBucket)
		bucket.Add("/projects/"+id+"/docker/a.txt", daysAgo(10))

		request, err := NewCleanRequest(artifact.ID.String())
		assert.Nil(t, err)

		cleaner := NewBatchCleaner(s, request, 10)
		_, err = cleaner.Run(db.Conn())
		assert.NoError(t, err)
		assert.Equal(t, bucket.Size(), 0)
		assert.True(t, cleaner.artifactDeleted)
	})

	t.Run("purges a storage that never had a retention policy", func(t *testing.T) {
		artifact, err := models.CreateArtifact(uuid.NewV4().String(), uuid.NewV4().String())
		assert.NoError(t, err)

		assert.NoError(t, privateapi.DestroyArtifact(context.TODO(), s, artifact.ID.String()))

		bucket := s.GetBucket(storage.BucketOptions{Name: artifact.BucketName}).(*storage.InMemoryBucket)
		bucket.Add("/projects/"+id+"/docker/a.txt", daysAgo(10))

		request, err := NewCleanRequest(artifact.ID.String())
		assert.Nil(t, err)

		cleaner := NewBatchCleaner(s, request, 10)
		_, err = cleaner.Run(db.Conn())
		assert.NoError(t, err)
		assert.Equal(t, bucket.Size(), 0)
		assert.True(t, cleaner.artifactDeleted)
	})
}
