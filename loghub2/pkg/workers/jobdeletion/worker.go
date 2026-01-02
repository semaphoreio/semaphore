package jobdeletion

import (
	"context"
	"errors"
	"log"
	"os"
	"time"

	gcs "cloud.google.com/go/storage"
	tackle "github.com/renderedtext/go-tackle"
	server_farm_job "github.com/semaphoreio/semaphore/loghub2/pkg/protos/server_farm.job"
	"github.com/semaphoreio/semaphore/loghub2/pkg/storage"
	"google.golang.org/protobuf/proto"
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
	event := &server_farm_job.JobDeleted{}

	err := proto.Unmarshal(delivery.Body(), event)
	if err != nil {
		log.Printf("JobDeletion Worker: Failed to parse message: %s, error: %+v", delivery.Body(), err)
		return err
	}

	ctx := context.Background()
	jobID := event.GetJobId()

	exists, err := w.storageClient.Exists(ctx, jobID)
	if err != nil && !errors.Is(err, gcs.ErrObjectNotExist) {
		log.Printf("JobDeletion Worker: Error checking if logs exist for JobID=%s: %v", jobID, err)
		return err
	}

	if !exists {
		log.Printf("JobDeletion Worker: No logs found for JobID=%s", jobID)
		return nil
	}

	err = w.storageClient.DeleteFile(ctx, jobID)
	if err != nil {
		log.Printf("JobDeletion Worker: Error deleting logs for JobID=%s: %v", jobID, err)
		return err
	}

	log.Printf("JobDeletion Worker: Successfully deleted logs for JobID=%s", jobID)
	return nil
}
