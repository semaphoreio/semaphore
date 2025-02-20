package bucketcleaner

import (
	"fmt"
	"log"
	"os"
	"testing"
	"time"

	uuid "github.com/satori/go.uuid"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/models"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/storage"
	"github.com/stretchr/testify/assert"
)

func Test__E2E(t *testing.T) {
	models.PrepareDatabaseForTests()

	//
	// Step 1. Create buckets and retention policies
	//

	s := storage.NewInMemoryStorage()
	artifact, policy := createBucketWithRetentionPolicy(t)
	bucket := s.GetBucket(storage.BucketOptions{Name: artifact.BucketName}).(*storage.InMemoryBucket)

	//
	// Step 2. Populate the bucket with objects
	//

	path := func(artifactType, path string) string {
		return fmt.Sprintf("/%s/%s%s", artifactType, uuid.NewV4().String(), path)
	}

	iterations := 20
	expectedLeftoverObjects := 3 * iterations

	for i := 0; i < iterations; i++ {
		bucket.Add(path("project", "/docker/b.txt"), daysAgo(10))         // won't be deleted
		bucket.Add(path("workflows", "/test-results/a.txt"), daysAgo(10)) // will be deleted
		bucket.Add(path("workflows", "/test-results/b.txt"), daysAgo(1))  // won't be deleted
		bucket.Add(path("jobs", "/test-results/a.txt"), daysAgo(10))      // will be deleted
		bucket.Add(path("jobs", "/test-results/b.txt"), daysAgo(1))       // won't be deleted
	}

	//
	// Step 3. Set up schedulers and workers
	//

	amqpURL := os.Getenv("AMQP_URL")

	scheduler, err := NewScheduler(amqpURL, 1*time.Second, 10)
	assert.Nil(t, err)

	worker, err := NewWorker(amqpURL, s)
	worker.NumberOfPagesToProcessInOneGo = iterations / 2
	assert.Nil(t, err)

	scheduler.Start()
	defer scheduler.Stop()

	worker.Start()
	defer worker.Stop()

	//
	// Step 4. Wait until everything is properly cleaned
	//
	assert.Eventually(t, func() bool {
		policy.Reload()

		scheduled := policy.ScheduledForCleaningAt != nil
		cleaned := policy.LastCleanedAt != nil
		areFilesDeleted := bucket.Size() == expectedLeftoverObjects

		log.Printf("Number of files in the bucket %d\n", bucket.Size())
		log.Printf("Scheduled: %v\n", policy.ScheduledForCleaningAt)
		log.Printf("Cleaned: %v\n", policy.LastCleanedAt)

		return scheduled && cleaned && areFilesDeleted
	}, 30*time.Second, 1*time.Second)
}
