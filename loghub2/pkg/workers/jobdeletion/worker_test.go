package jobdeletion

import (
	"context"
	"io"
	"os"
	"testing"
	"time"

	tackle "github.com/renderedtext/go-tackle"
	server_farm_job "github.com/semaphoreio/semaphore/loghub2/pkg/protos/server_farm.job"
	"github.com/semaphoreio/semaphore/loghub2/pkg/storage"
	"github.com/stretchr/testify/assert"
	"google.golang.org/protobuf/proto"
	"google.golang.org/protobuf/types/known/timestamppb"
)

type mockStorage struct {
	files       map[string]bool
	deleteError error
}

func newMockStorage() *mockStorage {
	return &mockStorage{
		files: make(map[string]bool),
	}
}

func (m *mockStorage) SaveFile(ctx context.Context, fileName, key string) error {
	m.files[key] = true
	return nil
}

func (m *mockStorage) Exists(ctx context.Context, fileName string) (bool, error) {
	exists, _ := m.files[fileName]
	return exists, nil
}

func (m *mockStorage) ReadFile(ctx context.Context, fileName string) ([]byte, error) {
	return nil, nil
}

func (m *mockStorage) ReadFileAsReader(ctx context.Context, fileName string) (io.ReadCloser, error) {
	return nil, nil
}

func (m *mockStorage) DeleteFile(ctx context.Context, fileName string) error {
	if m.deleteError != nil {
		return m.deleteError
	}
	delete(m.files, fileName)
	return nil
}

func Test__JobDeletionWorker(t *testing.T) {
	mockStore := newMockStorage()
	worker, err := NewWorker(os.Getenv("AMQP_URL"), mockStore)
	assert.Nil(t, err)

	t.Run("it can boot up and shut down", func(t *testing.T) {
		worker.Start()
		time.Sleep(100 * time.Millisecond)

		worker.Stop()
		time.Sleep(100 * time.Millisecond)
	})

	t.Run("it deletes logs when job deletion event is received", func(t *testing.T) {
		mockStore := newMockStorage()
		worker, err := NewWorker(os.Getenv("AMQP_URL"), mockStore)
		assert.Nil(t, err)

		worker.Start()
		defer worker.Stop()

		jobID := "test-job-123"
		mockStore.files[jobID] = true

		event := &server_farm_job.JobDeleted{
			JobId:          jobID,
			OrganizationId: "org-123",
			ProjectId:      "proj-123",
			DeletedAt:      timestamppb.Now(),
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

		assert.Eventually(t, func() bool {
			_, exists := mockStore.files[jobID]
			return !exists
		}, 10*time.Second, 100*time.Millisecond)
	})

	t.Run("it handles case when logs don't exist", func(t *testing.T) {
		mockStore := newMockStorage()
		worker, err := NewWorker(os.Getenv("AMQP_URL"), mockStore)
		assert.Nil(t, err)

		worker.Start()
		defer worker.Stop()

		jobID := "non-existent-job"

		event := &server_farm_job.JobDeleted{
			JobId:          jobID,
			OrganizationId: "org-123",
			ProjectId:      "proj-123",
			DeletedAt:      timestamppb.Now(),
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

		time.Sleep(1 * time.Second)
		_, exists := mockStore.files[jobID]
		assert.False(t, exists)
	})
}
