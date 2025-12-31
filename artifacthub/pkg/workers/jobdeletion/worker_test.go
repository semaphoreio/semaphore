package jobdeletion

import (
	"context"
	"os"
	"testing"
	"time"

	uuid "github.com/satori/go.uuid"
	tackle "github.com/renderedtext/go-tackle"
	server_farm_job "github.com/semaphoreio/semaphore/artifacthub/pkg/api/descriptors/server_farm.job"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/models"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/storage"
	"github.com/stretchr/testify/assert"
	"google.golang.org/protobuf/proto"
	"google.golang.org/protobuf/types/known/timestamppb"
)

func Test__JobDeletionWorker(t *testing.T) {
	models.PrepareDatabaseForTests()

	storageClient := storage.NewInMemoryStorage()
	worker, err := NewWorker(os.Getenv("AMQP_URL"), storageClient)
	assert.Nil(t, err)

	t.Run("it can boot up and shut down", func(t *testing.T) {
		worker.Start()
		time.Sleep(100 * time.Millisecond)

		worker.Stop()
		time.Sleep(100 * time.Millisecond)
	})

	t.Run("it deletes artifacts when job deletion event is received", func(t *testing.T) {
		storageClient := storage.NewInMemoryStorage()
		worker, err := NewWorker(os.Getenv("AMQP_URL"), storageClient)
		assert.Nil(t, err)

		worker.Start()
		defer worker.Stop()

		// Create an artifact store in the database
		bucketName := uuid.NewV4().String()
		idempotencyToken := uuid.NewV4().String()
		artifact, err := models.CreateArtifact(bucketName, idempotencyToken)
		assert.Nil(t, err)

		jobID := "test-job-456"
		jobPath := "artifacts/jobs/" + jobID + "/"

		// Create some fake artifacts in storage
		bucket := storageClient.GetBucket(storage.BucketOptions{
			Name:       bucketName,
			PathPrefix: idempotencyToken,
		})

		ctx := context.Background()
		err = bucket.CreatePath(ctx, jobPath+"file1.txt", []byte("content1"))
		assert.Nil(t, err)
		err = bucket.CreatePath(ctx, jobPath+"file2.txt", []byte("content2"))
		assert.Nil(t, err)

		// Publish job deletion event
		event := &server_farm_job.JobDeleted{
			JobId:           jobID,
			OrganizationId:  "org-456",
			ProjectId:       "proj-456",
			ArtifactStoreId: artifact.ID.String(),
			DeletedAt:       timestamppb.Now(),
		}

		body, err := proto.Marshal(event)
		assert.Nil(t, err)

		err = tackle.PublishMessage(&tackle.PublishParams{
			AmqpURL:    os.Getenv("AMQP_URL"),
			Body:       body,
			Exchange:   JobDeletionExchange,
			RoutingKey: JobDeletionRoutingKey,
		})
		assert.Nil(t, err)

		// Verify artifacts are deleted
		assert.Eventually(t, func() bool {
			exists, _ := bucket.PathExists(ctx, jobPath+"file1.txt")
			return !exists
		}, 10*time.Second, 100*time.Millisecond)

		exists, _ := bucket.PathExists(ctx, jobPath+"file2.txt")
		assert.False(t, exists)
	})

	t.Run("it handles case when artifact store doesn't exist", func(t *testing.T) {
		storageClient := storage.NewInMemoryStorage()
		worker, err := NewWorker(os.Getenv("AMQP_URL"), storageClient)
		assert.Nil(t, err)

		worker.Start()
		defer worker.Stop()

		// Use a non-existent artifact store ID
		fakeArtifactStoreID := uuid.NewV4().String()
		jobID := "test-job-789"

		event := &server_farm_job.JobDeleted{
			JobId:           jobID,
			OrganizationId:  "org-789",
			ProjectId:       "proj-789",
			ArtifactStoreId: fakeArtifactStoreID,
			DeletedAt:       timestamppb.Now(),
		}

		body, err := proto.Marshal(event)
		assert.Nil(t, err)

		err = tackle.PublishMessage(&tackle.PublishParams{
			AmqpURL:    os.Getenv("AMQP_URL"),
			Body:       body,
			Exchange:   JobDeletionExchange,
			RoutingKey: JobDeletionRoutingKey,
		})
		assert.Nil(t, err)

		// Just verify the worker doesn't crash - message will be retried
		time.Sleep(1 * time.Second)
	})

	t.Run("it handles case when no artifacts exist for job", func(t *testing.T) {
		storageClient := storage.NewInMemoryStorage()
		worker, err := NewWorker(os.Getenv("AMQP_URL"), storageClient)
		assert.Nil(t, err)

		worker.Start()
		defer worker.Stop()

		// Create an artifact store in the database
		bucketName := uuid.NewV4().String()
		idempotencyToken := uuid.NewV4().String()
		artifact, err := models.CreateArtifact(bucketName, idempotencyToken)
		assert.Nil(t, err)

		jobID := "test-job-no-artifacts"

		// Publish job deletion event (no artifacts created)
		event := &server_farm_job.JobDeleted{
			JobId:           jobID,
			OrganizationId:  "org-999",
			ProjectId:       "proj-999",
			ArtifactStoreId: artifact.ID.String(),
			DeletedAt:       timestamppb.Now(),
		}

		body, err := proto.Marshal(event)
		assert.Nil(t, err)

		err = tackle.PublishMessage(&tackle.PublishParams{
			AmqpURL:    os.Getenv("AMQP_URL"),
			Body:       body,
			Exchange:   JobDeletionExchange,
			RoutingKey: JobDeletionRoutingKey,
		})
		assert.Nil(t, err)

		// Worker should handle this gracefully
		time.Sleep(1 * time.Second)
	})
}
