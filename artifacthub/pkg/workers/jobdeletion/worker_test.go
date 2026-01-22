package jobdeletion

import (
	"context"
	"errors"
	"testing"

	uuid "github.com/satori/go.uuid"
	server_farm_job "github.com/semaphoreio/semaphore/artifacthub/pkg/api/descriptors/server_farm.job"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/models"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/storage"
	"github.com/stretchr/testify/assert"
	"google.golang.org/protobuf/proto"
	"google.golang.org/protobuf/types/known/timestamppb"
)

// mockDelivery implements tackle.Delivery interface for testing
type mockDelivery struct {
	ackWillFail  bool
	nackWillFail bool
	body         []byte
}

func (m *mockDelivery) Ack() error {
	if m.ackWillFail {
		return errors.New("Ack failed")
	}
	return nil
}

func (m *mockDelivery) Body() []byte {
	return m.body
}

func (m *mockDelivery) Nack(requeue bool) error {
	if m.nackWillFail {
		return errors.New("Nack failed")
	}
	return nil
}

func Test__HandleMessage(t *testing.T) {
	models.PrepareDatabaseForTests()

	t.Run("invalid protobuf returns error", func(t *testing.T) {
		worker, _ := NewWorker("", storage.NewInMemoryStorage(), 0)
		delivery := &mockDelivery{body: []byte("invalid")}

		err := worker.handleMessage(delivery)

		assert.NotNil(t, err)
	})

	t.Run("artifact store not found returns error", func(t *testing.T) {
		worker, _ := NewWorker("", storage.NewInMemoryStorage(), 0)

		event := &server_farm_job.JobDeleted{
			JobId:           uuid.NewV4().String(),
			ArtifactStoreId: uuid.NewV4().String(),
			DeletedAt:       timestamppb.Now(),
		}
		body, _ := proto.Marshal(event)
		delivery := &mockDelivery{body: body}

		err := worker.handleMessage(delivery)

		assert.NotNil(t, err)
	})

	t.Run("deletes artifacts successfully", func(t *testing.T) {
		storageClient := storage.NewInMemoryStorage()
		worker, _ := NewWorker("", storageClient, 0)

		artifact, _ := models.CreateArtifact(uuid.NewV4().String(), uuid.NewV4().String())
		jobID := uuid.NewV4().String()

		bucket := storageClient.GetBucket(storage.BucketOptions{
			Name:       artifact.BucketName,
			PathPrefix: artifact.IdempotencyToken,
		})
		bucket.CreateObject(context.Background(), "artifacts/jobs/"+jobID+"/file.txt", []byte("data"))

		event := &server_farm_job.JobDeleted{
			JobId:           jobID,
			ArtifactStoreId: artifact.ID.String(),
			DeletedAt:       timestamppb.Now(),
		}
		body, _ := proto.Marshal(event)
		delivery := &mockDelivery{body: body}

		err := worker.handleMessage(delivery)

		assert.Nil(t, err)
		exists, _ := bucket.IsFile(context.Background(), "artifacts/jobs/"+jobID+"/file.txt")
		assert.False(t, exists)
	})
}
