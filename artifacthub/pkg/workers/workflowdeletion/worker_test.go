package workflowdeletion

import (
	"context"
	"errors"
	"testing"

	uuid "github.com/satori/go.uuid"
	plumber_wf "github.com/semaphoreio/semaphore/artifacthub/pkg/api/descriptors/plumber_w_f.workflow"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/models"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/storage"
	"github.com/stretchr/testify/assert"
	"google.golang.org/protobuf/proto"
	"google.golang.org/protobuf/types/known/timestamppb"
)

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
		worker, _ := NewWorker("", storage.NewInMemoryStorage())
		delivery := &mockDelivery{body: []byte("invalid")}

		err := worker.handleMessage(delivery)

		assert.NotNil(t, err)
	})

	t.Run("missing workflowID returns error", func(t *testing.T) {
		worker, _ := NewWorker("", storage.NewInMemoryStorage())

		event := &plumber_wf.WorkflowDeleted{
			WorkflowId:      "",
			ArtifactStoreId: uuid.NewV4().String(),
			DeletedAt:       timestamppb.Now(),
		}
		body, _ := proto.Marshal(event)
		delivery := &mockDelivery{body: body}

		err := worker.handleMessage(delivery)

		assert.NotNil(t, err)
	})

	t.Run("missing artifact store skips deletion", func(t *testing.T) {
		worker, _ := NewWorker("", storage.NewInMemoryStorage())

		event := &plumber_wf.WorkflowDeleted{
			WorkflowId:      uuid.NewV4().String(),
			ArtifactStoreId: "",
			DeletedAt:       timestamppb.Now(),
		}
		body, _ := proto.Marshal(event)
		delivery := &mockDelivery{body: body}

		err := worker.handleMessage(delivery)

		assert.Nil(t, err)
	})

	t.Run("artifact store not found returns error", func(t *testing.T) {
		worker, _ := NewWorker("", storage.NewInMemoryStorage())

		event := &plumber_wf.WorkflowDeleted{
			WorkflowId:      uuid.NewV4().String(),
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
		worker, _ := NewWorker("", storageClient)

		artifact, _ := models.CreateArtifact(uuid.NewV4().String(), uuid.NewV4().String())
		workflowID := uuid.NewV4().String()

		bucket := storageClient.GetBucket(storage.BucketOptions{
			Name:       artifact.BucketName,
			PathPrefix: artifact.IdempotencyToken,
		})
		bucket.CreateObject(context.Background(), "artifacts/workflows/"+workflowID+"/file.txt", []byte("data"))

		event := &plumber_wf.WorkflowDeleted{
			WorkflowId:      workflowID,
			ArtifactStoreId: artifact.ID.String(),
			DeletedAt:       timestamppb.Now(),
		}
		body, _ := proto.Marshal(event)
		delivery := &mockDelivery{body: body}

		err := worker.handleMessage(delivery)

		assert.Nil(t, err)
		exists, _ := bucket.IsFile(context.Background(), "artifacts/workflows/"+workflowID+"/file.txt")
		assert.False(t, exists)
	})
}
