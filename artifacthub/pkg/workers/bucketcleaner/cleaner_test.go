package bucketcleaner

import (
	"context"
	"errors"
	"fmt"
	"os"
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

	// These cover what a purge does once it is due. The wait before it becomes due
	// is covered by Test__CleanerPurgeGracePeriod.
	withGracePeriod(t, 0)

	t.Run("a purged storage loses everything, whatever the rules say", func(t *testing.T) {
		artifact, _ := createBucketWithRetentionPolicy(t)
		bucket := s.GetBucket(storage.BucketOptions{Name: artifact.BucketName}).(*storage.InMemoryBucket)

		// None of these would be deleted under the policy: the paths do not match
		// its selectors, and the objects are younger than the one day floor that
		// even a matching rule has to clear.
		bucket.Add("/projects/"+id+"/docker/b.txt", daysAgo(0))
		bucket.Add("/workflows/"+id+"/junit/a.txt", daysAgo(0))
		bucket.Add("/jobs/"+id+"/junit/b.txt", daysAgo(0))

		assert.NoError(t, privateapi.PurgeArtifactContents(artifact.IdempotencyToken, time.Now()))

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
		assert.NoError(t, privateapi.PurgeArtifactContents(artifact.IdempotencyToken, time.Now()))

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

		assert.NoError(t, privateapi.PurgeArtifactContents(artifact.IdempotencyToken, time.Now()))

		request, err := NewCleanRequest(artifact.ID.String())
		assert.Nil(t, err)

		cleaner := NewBatchCleaner(s, request, 10)
		_, err = cleaner.Run(db.Conn())
		assert.NoError(t, err)
		assert.Equal(t, 0, bucket.Size())
	})

	t.Run("the end of a longer chain leaves the mark for a pass from the first page", func(t *testing.T) {
		artifact, _ := createBucketWithRetentionPolicy(t)
		bucket := s.GetBucket(storage.BucketOptions{Name: artifact.BucketName}).(*storage.InMemoryBucket)

		for i := 0; i < 150; i++ {
			require.NoError(t, bucket.Add(fmt.Sprintf("/jobs/%s/junit/%d.txt", id, i), daysAgo(0)))
		}

		require.NoError(t, privateapi.PurgeArtifactContents(artifact.IdempotencyToken, time.Now()))

		request, err := NewCleanRequest(artifact.ID.String())
		require.NoError(t, err)

		// One page per run, so the purge takes a chain of two messages.
		token, err := NewBatchCleaner(s, request, 1).Run(db.Conn())
		require.NoError(t, err)
		require.NotEmpty(t, token)

		request.PaginationToken = token
		last := NewBatchCleaner(s, request, 1)
		token, err = last.Run(db.Conn())
		require.NoError(t, err)
		require.Empty(t, token)

		// Everything is gone, but a run that began mid-bucket cannot vouch for all of it.
		assert.Zero(t, bucket.Size())
		assert.False(t, last.purgeCompleted)
		stored, err := models.FindArtifactByID(artifact.ID.String())
		require.NoError(t, err)
		assert.NotNil(t, stored.PurgeRequestedAt)

		request.PaginationToken = ""
		check := NewBatchCleaner(s, request, 1)
		_, err = check.Run(db.Conn())
		require.NoError(t, err)
		assert.True(t, check.purgeCompleted)

		stored, err = models.FindArtifactByID(artifact.ID.String())
		require.NoError(t, err)
		assert.Nil(t, stored.PurgeRequestedAt)
	})

	t.Run("a purged storage is destroyed when its project is destroyed", func(t *testing.T) {
		artifact, _ := createBucketWithRetentionPolicy(t)
		assert.NoError(t, privateapi.PurgeArtifactContents(artifact.IdempotencyToken, time.Now()))

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

	withGracePeriod(t, 0)

	t.Run("a purge whose deletes fail reports the failure and keeps its mark", func(t *testing.T) {
		artifact, _ := createBucketWithRetentionPolicy(t)
		bucket := s.GetBucket(storage.BucketOptions{Name: artifact.BucketName}).(*storage.InMemoryBucket)

		bucket.Add("/jobs/"+id+"/junit/a.txt", daysAgo(10))
		bucket.DeleteObjectsError = errors.New("failed to delete 1 of 1 objects")

		assert.NoError(t, privateapi.PurgeArtifactContents(artifact.IdempotencyToken, time.Now()))

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
		assert.NoError(t, privateapi.PurgeArtifactContents(artifact.IdempotencyToken, time.Now()))

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

func Test__CleanerPurgeGracePeriod(t *testing.T) {
	models.PrepareDatabaseForTests()
	s := storage.NewInMemoryStorage()
	id := uuid.NewV4().String()

	withGracePeriod(t, 72*time.Hour)

	t.Run("a marked storage keeps its contents until the grace period is up", func(t *testing.T) {
		artifact, _ := createBucketWithRetentionPolicy(t)
		bucket := s.GetBucket(storage.BucketOptions{Name: artifact.BucketName}).(*storage.InMemoryBucket)

		bucket.Add("/jobs/"+id+"/junit/a.txt", daysAgo(0))

		require.NoError(t, privateapi.PurgeArtifactContents(artifact.IdempotencyToken, time.Now()))

		request, err := NewCleanRequest(artifact.ID.String())
		require.NoError(t, err)

		cleaner := NewBatchCleaner(s, request, 10)
		_, err = cleaner.Run(db.Conn())
		require.NoError(t, err)

		// Still there to be restored along with the project, which is the point of
		// the wait.
		assert.Equal(t, 1, bucket.Size())
		assert.Zero(t, cleaner.deletedObjectCount)
		assert.False(t, cleaner.purgeCompleted)

		// And the mark stays on, so the purge still happens once the wait is over.
		stored, err := models.FindArtifactByID(artifact.ID.String())
		require.NoError(t, err)
		assert.NotNil(t, stored.PurgeRequestedAt)
	})

	t.Run("waiting applies the retention policy as usual, rather than nothing at all", func(t *testing.T) {
		artifact, _ := createBucketWithRetentionPolicy(t)
		bucket := s.GetBucket(storage.BucketOptions{Name: artifact.BucketName}).(*storage.InMemoryBucket)

		// Old enough for the policy to delete, which it must still do: a marked
		// storage is not exempt from routine retention while it waits.
		bucket.Add("/jobs/"+id+"/junit/a.txt", daysAgo(10))
		bucket.Add("/jobs/"+id+"/junit/b.txt", daysAgo(0))

		require.NoError(t, privateapi.PurgeArtifactContents(artifact.IdempotencyToken, time.Now()))

		request, err := NewCleanRequest(artifact.ID.String())
		require.NoError(t, err)

		cleaner := NewBatchCleaner(s, request, 10)
		_, err = cleaner.Run(db.Conn())
		require.NoError(t, err)

		assert.Equal(t, 1, cleaner.deletedObjectCount)
		assert.Equal(t, 1, bucket.Size())
		assert.False(t, cleaner.purgeCompleted)
	})

	t.Run("once the grace period has passed the storage is emptied", func(t *testing.T) {
		artifact, _ := createBucketWithRetentionPolicy(t)
		bucket := s.GetBucket(storage.BucketOptions{Name: artifact.BucketName}).(*storage.InMemoryBucket)

		bucket.Add("/jobs/"+id+"/junit/a.txt", daysAgo(0))

		require.NoError(t, privateapi.PurgeArtifactContents(artifact.IdempotencyToken, time.Now()))
		require.NoError(t, agePurgeMark(artifact.ID, 73*time.Hour))

		request, err := NewCleanRequest(artifact.ID.String())
		require.NoError(t, err)

		cleaner := NewBatchCleaner(s, request, 10)
		_, err = cleaner.Run(db.Conn())
		require.NoError(t, err)

		assert.Zero(t, bucket.Size())
		assert.True(t, cleaner.purgeCompleted)
	})

	t.Run("restoring inside the grace period leaves the artifacts alone", func(t *testing.T) {
		artifact, _ := createBucketWithRetentionPolicy(t)
		bucket := s.GetBucket(storage.BucketOptions{Name: artifact.BucketName}).(*storage.InMemoryBucket)

		bucket.Add("/jobs/"+id+"/junit/a.txt", daysAgo(0))

		require.NoError(t, privateapi.PurgeArtifactContents(artifact.IdempotencyToken, time.Now()))
		require.NoError(t, privateapi.CancelArtifactPurge(artifact.IdempotencyToken, time.Now()))

		// Even long after the window would have closed, because the mark is gone.
		request, err := NewCleanRequest(artifact.ID.String())
		require.NoError(t, err)

		cleaner := NewBatchCleaner(s, request, 10)
		_, err = cleaner.Run(db.Conn())
		require.NoError(t, err)

		assert.Equal(t, 1, bucket.Size())
		assert.False(t, cleaner.purgeCompleted)
	})

	t.Run("destruction is not held back by the grace period", func(t *testing.T) {
		artifact, _ := createBucketWithRetentionPolicy(t)
		bucket := s.GetBucket(storage.BucketOptions{Name: artifact.BucketName}).(*storage.InMemoryBucket)

		bucket.Add("/jobs/"+id+"/junit/a.txt", daysAgo(0))

		// A project is only destroyed after its own 30 day grace period, so there is
		// nothing left to wait for.
		require.NoError(t, privateapi.DestroyArtifact(context.TODO(), s, artifact.ID.String()))

		request, err := NewCleanRequest(artifact.ID.String())
		require.NoError(t, err)

		cleaner := NewBatchCleaner(s, request, 10)
		_, err = cleaner.Run(db.Conn())
		require.NoError(t, err)

		assert.Zero(t, bucket.Size())
	})
}

// On S3 every project shares one bucket, and only the path prefix keeps them apart.
func Test__CleanerStaysInsideItsProject(t *testing.T) {
	models.PrepareDatabaseForTests()
	withGracePeriod(t, time.Hour)

	storage.RunTestForAllBackends(t, func(backend string, client storage.Client) {
		t.Run(backend, func(t *testing.T) {
			objects := []storage.SeedObject{
				{Name: "artifacts/jobs/a/file.txt", Content: "a"},
				{Name: "artifacts/workflows/b/file.txt", Content: "b"},
			}

			// One token is a string prefix of the other, which pins the boundary between them.
			deletedToken := uuid.NewV4().String()
			keptToken := deletedToken + "-other"

			seed := func(token string) (*models.Artifact, storage.Bucket) {
				bucketName, err := client.CreateBucket(context.TODO())
				require.NoError(t, err)

				artifact, err := models.CreateArtifact(bucketName, token)
				require.NoError(t, err)

				bucket := client.GetBucket(storage.BucketOptions{Name: bucketName, PathPrefix: token})
				require.NoError(t, storage.SeedBucket(bucket, objects))

				return artifact, bucket
			}

			deleted, deletedBucket := seed(deletedToken)
			_, keptBucket := seed(keptToken)

			run := func() *BatchCleaner {
				request, err := NewCleanRequest(deleted.ID.String())
				require.NoError(t, err)

				cleaner := NewBatchCleaner(client, request, 10)
				_, err = cleaner.Run(db.Conn())
				require.NoError(t, err)

				return cleaner
			}

			require.NoError(t, privateapi.PurgeArtifactContents(deletedToken, time.Now().Add(-2*time.Hour)))
			assert.True(t, run().purgeCompleted)
			assert.Zero(t, countObjects(t, deletedBucket))
			assert.Equal(t, len(objects), countObjects(t, keptBucket))

			require.NoError(t, privateapi.DestroyArtifact(context.TODO(), client, deleted.ID.String()))
			assert.True(t, run().artifactDeleted)
			assert.Equal(t, len(objects), countObjects(t, keptBucket))
		})
	})
}

func countObjects(t *testing.T, bucket storage.Bucket) int {
	pager, err := bucket.ListObjectsWithPagination(storage.ListOptions{Path: "artifacts/"})
	require.NoError(t, err)

	count := 0
	for {
		objects, next, err := pager.NextPage()
		require.NoError(t, err)

		count += len(objects)
		if next == "" {
			return count
		}
	}
}

// Turning the feature off has to stop purges already marked, not only new marks.
func Test__CleanerPurgeDisabled(t *testing.T) {
	models.PrepareDatabaseForTests()
	s := storage.NewInMemoryStorage()

	withGracePeriod(t, time.Hour)
	withPurgeEnabled(t, false)

	t.Run("a due purge deletes nothing and keeps its mark", func(t *testing.T) {
		artifact, _ := createBucketWithRetentionPolicy(t)
		bucket := s.GetBucket(storage.BucketOptions{Name: artifact.BucketName}).(*storage.InMemoryBucket)
		bucket.Add("/jobs/a/junit/a.txt", daysAgo(0))

		require.NoError(t, privateapi.PurgeArtifactContents(artifact.IdempotencyToken, time.Now().Add(-2*time.Hour)))

		assert.False(t, runCleaner(t, s, artifact).purgeCompleted)
		assert.Equal(t, 1, bucket.Size())

		stored, err := models.FindArtifactByID(artifact.ID.String())
		require.NoError(t, err)
		assert.NotNil(t, stored.PurgeRequestedAt)
	})

	t.Run("destruction still goes ahead", func(t *testing.T) {
		artifact, _ := createBucketWithRetentionPolicy(t)
		bucket := s.GetBucket(storage.BucketOptions{Name: artifact.BucketName}).(*storage.InMemoryBucket)
		bucket.Add("/jobs/a/junit/a.txt", daysAgo(0))

		require.NoError(t, privateapi.DestroyArtifact(context.TODO(), s, artifact.ID.String()))

		runCleaner(t, s, artifact)
		assert.Zero(t, bucket.Size())
	})
}

// On GCS every storage has a bucket of its own, so one whose bucket is gone holds nothing.
func Test__CleanerBucketGone(t *testing.T) {
	models.PrepareDatabaseForTests()
	withGracePeriod(t, time.Hour)

	gcs, err := storage.NewGcsClient("")
	require.NoError(t, err)

	goneStorage := func(t *testing.T) *models.Artifact {
		artifact, err := models.CreateArtifact("gone-"+uuid.NewV4().String(), uuid.NewV4().String())
		require.NoError(t, err)

		return artifact
	}

	t.Run("a purge finishes and clears its mark", func(t *testing.T) {
		artifact := goneStorage(t)
		require.NoError(t, privateapi.PurgeArtifactContents(artifact.IdempotencyToken, time.Now().Add(-2*time.Hour)))

		assert.True(t, runCleaner(t, gcs, artifact).purgeCompleted)

		stored, err := models.FindArtifactByID(artifact.ID.String())
		require.NoError(t, err)
		assert.Nil(t, stored.PurgeRequestedAt)
	})

	t.Run("a destruction removes the row", func(t *testing.T) {
		artifact := goneStorage(t)
		require.NoError(t, privateapi.DestroyArtifact(context.TODO(), gcs, artifact.ID.String()))

		assert.True(t, runCleaner(t, gcs, artifact).artifactDeleted)

		_, err := models.FindArtifactByIdempotencyTokenRaw(db.Conn(), artifact.IdempotencyToken)
		assert.ErrorIs(t, err, gorm.ErrRecordNotFound)
	})

	// On S3 one bucket holds every storage, so a missing one is a configuration error.
	t.Run("a missing S3 bucket keeps failing", func(t *testing.T) {
		s3, err := storage.NewS3Client(storage.S3Options{
			URL:             os.Getenv("ARTIFACT_STORAGE_S3_URL"),
			BucketName:      "missing-" + uuid.NewV4().String(),
			AccessKeyID:     os.Getenv("AWS_ACCESS_KEY_ID"),
			SecretAccessKey: os.Getenv("AWS_SECRET_ACCESS_KEY"),
			Region:          os.Getenv("AWS_REGION"),
		})
		require.NoError(t, err)

		artifact := goneStorage(t)
		require.NoError(t, privateapi.PurgeArtifactContents(artifact.IdempotencyToken, time.Now().Add(-2*time.Hour)))

		request, err := NewCleanRequest(artifact.ID.String())
		require.NoError(t, err)

		_, err = NewBatchCleaner(s3, request, 10).Run(db.Conn())
		assert.Error(t, err)

		stored, err := models.FindArtifactByID(artifact.ID.String())
		require.NoError(t, err)
		assert.NotNil(t, stored.PurgeRequestedAt)
	})
}

func runCleaner(t *testing.T, client storage.Client, artifact *models.Artifact) *BatchCleaner {
	request, err := NewCleanRequest(artifact.ID.String())
	require.NoError(t, err)

	cleaner := NewBatchCleaner(client, request, 10)
	_, err = cleaner.Run(db.Conn())
	require.NoError(t, err)

	return cleaner
}

// withGracePeriod sets the package-wide grace period for one test and puts it back
// afterwards, since the cleaner and the scheduler both read it.
func withGracePeriod(t *testing.T, grace time.Duration) {
	t.Helper()

	previous := PurgeGracePeriod
	PurgeGracePeriod = grace

	t.Cleanup(func() { PurgeGracePeriod = previous })
}

// agePurgeMark backdates the mark, which is the only way to reach the far side of
// the grace period without waiting for it.
func agePurgeMark(artifactID uuid.UUID, by time.Duration) error {
	return db.Conn().
		Table("artifacts").
		Where("id = ?", artifactID.String()).
		Update("purge_requested_at", time.Now().Add(-by)).
		Error
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
