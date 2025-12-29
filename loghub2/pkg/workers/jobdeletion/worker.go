package jobdeletion

import (
	"context"
	"encoding/json"
	"log"
	"os"
	"time"

	tackle "github.com/renderedtext/go-tackle"
	"github.com/semaphoreio/semaphore/loghub2/pkg/storage"
)

type Worker struct {
	amqpOptions       *tackle.Options
	consumer          *tackle.Consumer
	storageClient     storage.Storage
	reconnectAttempts int
}

const (
	JobDeletionExchange    = "zebra.job_deletion_exchange"
	JobDeletionServiceName = "loghub2.jobdeletion.worker"
	JobDeletionRoutingKey  = "deleted"
)

type JobDeletionEvent struct {
	JobID          string `json:"job_id"`
	OrganizationID string `json:"organization_id"`
	ProjectID      string `json:"project_id"`
	DeletedAt      string `json:"deleted_at"`
}

func NewWorker(amqpURL string, client storage.Storage) (*Worker, error) {
	options := &tackle.Options{
		URL:            amqpURL,
		ConnectionName: workerConnName(),
		RemoteExchange: JobDeletionExchange,
		Service:        JobDeletionServiceName,
		RoutingKey:     JobDeletionRoutingKey,
	}

	consumer := tackle.NewConsumer()

	return &Worker{
		consumer:      consumer,
		amqpOptions:   options,
		storageClient: client,
	}, nil
}

func workerConnName() string {
	hostname := os.Getenv("HOSTNAME")
	if hostname == "" {
		return "loghub2.jobdeletion.worker"
	}
	return hostname
}

func (w *Worker) Start() {
	log.Printf("JobDeletion Worker: Starting consumer for exchange=%s routing_key=%s", JobDeletionExchange, JobDeletionRoutingKey)
	go func() {
		err := w.consumer.Start(w.amqpOptions, w.handleMessage)
		if err != nil {
			log.Printf("JobDeletion Worker: error starting consumer %s", err)

			w.reconnectAttempts++
			waitTime := max(w.reconnectAttempts*2, 60)
			time.Sleep(time.Duration(waitTime) * time.Second)
			w.Start()
		}
	}()
}

func (w *Worker) Stop() {
	w.consumer.Stop()
}

func (w *Worker) handleMessage(delivery tackle.Delivery) error {
	var event JobDeletionEvent

	err := json.Unmarshal(delivery.Body(), &event)
	if err != nil {
		log.Printf("JobDeletion Worker: Failed to parse message: %s, error: %+v", delivery.Body(), err)
		return err
	}

	// Delete log file from cloud storage (S3/GCS)
	// The job_id is used directly as the key for log storage
	err = w.storageClient.DeleteFile(context.Background(), event.JobID)
	if err != nil {
		log.Printf("JobDeletion Worker: Error deleting logs for JobID=%s: %v", event.JobID, err)
		return err
	}

	log.Printf("JobDeletion Worker: Successfully deleted logs for JobID=%s", event.JobID)
	return nil
}
