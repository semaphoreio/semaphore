package jobdeletion

import (
	"context"
	"errors"
	"io"
	"testing"

	"github.com/google/uuid"
	server_farm_job "github.com/semaphoreio/semaphore/loghub2/pkg/protos/server_farm.job"
	"github.com/stretchr/testify/assert"
	"google.golang.org/protobuf/proto"
	"google.golang.org/protobuf/types/known/timestamppb"
)

type mockStorage struct {
	files       map[string]bool
	existsError error
	deleteError error
}

func newMockStorage() *mockStorage {
	return &mockStorage{
		files: make(map[string]bool),
	}
}

func (m *mockStorage) SaveFile(ctx context.Context, fileName, key string) error {
	return nil
}

func (m *mockStorage) Exists(ctx context.Context, fileName string) (bool, error) {
	if m.existsError != nil {
		return false, m.existsError
	}
	return m.files[fileName], nil
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

type mockDelivery struct {
	body []byte
}

func (m *mockDelivery) Ack() error {
	return nil
}

func (m *mockDelivery) Body() []byte {
	return m.body
}

func (m *mockDelivery) Nack(requeue bool) error {
	return nil
}

func Test__HandleMessage(t *testing.T) {
	t.Run("invalid protobuf returns error", func(t *testing.T) {
		mockStore := newMockStorage()
		worker, _ := NewWorker("", mockStore)
		delivery := &mockDelivery{body: []byte("invalid")}

		err := worker.handleMessage(delivery)

		assert.NotNil(t, err)
	})

	t.Run("file does not exist returns nil", func(t *testing.T) {
		mockStore := newMockStorage()
		worker, _ := NewWorker("", mockStore)

		jobID := uuid.New().String()
		event := &server_farm_job.JobDeleted{
			JobId:     jobID,
			DeletedAt: timestamppb.Now(),
		}
		body, _ := proto.Marshal(event)
		delivery := &mockDelivery{body: body}

		err := worker.handleMessage(delivery)

		assert.Nil(t, err)
	})

	t.Run("deletes file successfully", func(t *testing.T) {
		mockStore := newMockStorage()
		worker, _ := NewWorker("", mockStore)

		jobID := uuid.New().String()
		mockStore.files[jobID] = true

		event := &server_farm_job.JobDeleted{
			JobId:     jobID,
			DeletedAt: timestamppb.Now(),
		}
		body, _ := proto.Marshal(event)
		delivery := &mockDelivery{body: body}

		err := worker.handleMessage(delivery)

		assert.Nil(t, err)
		assert.False(t, mockStore.files[jobID])
	})

	t.Run("delete fails returns error", func(t *testing.T) {
		mockStore := newMockStorage()
		mockStore.deleteError = errors.New("delete failed")
		worker, _ := NewWorker("", mockStore)

		jobID := uuid.New().String()
		mockStore.files[jobID] = true

		event := &server_farm_job.JobDeleted{
			JobId:     jobID,
			DeletedAt: timestamppb.Now(),
		}
		body, _ := proto.Marshal(event)
		delivery := &mockDelivery{body: body}

		err := worker.handleMessage(delivery)

		assert.NotNil(t, err)
		assert.Equal(t, "delete failed", err.Error())
	})

	t.Run("exists check fails returns error", func(t *testing.T) {
		mockStore := newMockStorage()
		mockStore.existsError = errors.New("exists check failed")
		worker, _ := NewWorker("", mockStore)

		jobID := uuid.New().String()
		event := &server_farm_job.JobDeleted{
			JobId:     jobID,
			DeletedAt: timestamppb.Now(),
		}
		body, _ := proto.Marshal(event)
		delivery := &mockDelivery{body: body}

		err := worker.handleMessage(delivery)

		assert.NotNil(t, err)
		assert.Equal(t, "exists check failed", err.Error())
	})
}
