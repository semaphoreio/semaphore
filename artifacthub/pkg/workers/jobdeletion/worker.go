package jobdeletion

import (
	"context"
	"errors"
	"fmt"
	"log"
	"os"
	"time"

	tackle "github.com/renderedtext/go-tackle"
	"github.com/renderedtext/go-watchman"
	server_farm_job "github.com/semaphoreio/semaphore/artifacthub/pkg/api/descriptors/server_farm.job"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/models"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/storage"
	"google.golang.org/protobuf/proto"
)

type Worker struct {
	amqpOptions       *tackle.Options
	consumer          *tackle.Consumer
	storageClient     storage.Client
	reconnectAttempts int
	idx               int
}

const (
	JobDeletionExchange    = "zebra.job_deletion_exchange"
	JobDeletionServiceName = "artifacthub.jobdeletion.worker"
	JobDeletionRoutingKey  = "deleted"
)

func NewWorker(amqpURL string, client storage.Client, idx int) (*Worker, error) {
	options := &tackle.Options{
		URL:            amqpURL,
		ConnectionName: workerConnName(idx),
		RemoteExchange: JobDeletionExchange,
		Service:        JobDeletionServiceName,
		RoutingKey:     JobDeletionRoutingKey,
	}

	consumer := tackle.NewConsumer()

	return &Worker{
		consumer:      consumer,
		amqpOptions:   options,
		storageClient: client,
		idx:           idx,
	}, nil
}

func workerConnName(idx int) string {
	hostname := os.Getenv("HOSTNAME")
	if hostname == "" {
		return fmt.Sprintf("artifacthub.jobdeletion.worker.%d", idx)
	}
	return fmt.Sprintf("%s.%d", hostname, idx)
}

func (w *Worker) Start() {
	log.Printf("JobDeletion Worker: Starting consumer for exchange=%s routing_key=%s", JobDeletionExchange, JobDeletionRoutingKey)
	go func() {
		for {
			err := w.consumer.Start(w.amqpOptions, w.handleMessage)
			if err != nil {
				log.Printf("JobDeletion Worker: error starting consumer %s", err)
				w.reconnectAttempts++
				waitTime := min(w.reconnectAttempts*2, 60)
				time.Sleep(time.Duration(waitTime) * time.Second)
				continue
			}
			break
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

	jobID := event.GetJobId()
	artifactStoreID := event.GetArtifactStoreId()

	if jobID == "" {
		log.Printf("JobDeletion Worker: Invalid message, missing jobID: %+v", event)
		return fmt.Errorf("invalid message, missing jobID")
	}

	if artifactStoreID == "" {
		log.Printf("JobDeletion Worker: Skipping job %s - no artifactStoreID", jobID)
		return nil
	}

	artifact, err := models.FindArtifactByID(artifactStoreID)
	if err != nil {
		log.Printf("JobDeletion Worker: Failed to find artifact store with ID=%s: %v", artifactStoreID, err)
		return err
	}

	bucketName := artifact.BucketName
	idempotencyToken := artifact.IdempotencyToken

	jobPath := fmt.Sprintf("artifacts/jobs/%s/", jobID)

	bucket := w.storageClient.GetBucket(storage.BucketOptions{
		Name:       bucketName,
		PathPrefix: idempotencyToken,
	})

	err = bucket.DeletePath(context.Background(), jobPath)
	if err != nil && !errors.Is(err, storage.ErrMissingBucket) {
		log.Printf("JobDeletion Worker: Error deleting artifacts at path %s: %v", jobPath, err)
		return err
	}

	err = watchman.Increment("retention.deleted.success")
	if err != nil {
		log.Printf("JobDeletion Worker: Failed to increment watchman counter: %v", err)
	}

	log.Printf("JobDeletion Worker: Successfully deleted artifacts at path %s for JobID=%s", jobPath, jobID)
	return nil
}
