package jobdeletion

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"

	tackle "github.com/renderedtext/go-tackle"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/storage"
)

type Worker struct {
	amqpOptions   *tackle.Options
	consumer      *tackle.Consumer
	storageClient storage.Client
}

const (
	JobDeletionExchange    = "zebra.job_deletion_exchange"
	JobDeletionServiceName = "artifacthub.jobdeletion.worker"
	JobDeletionRoutingKey  = "job.deleted"
)

type JobDeletionEvent struct {
	JobID           string `json:"job_id"`
	OrganizationID  string `json:"organization_id"`
	ProjectID       string `json:"project_id"`
	ArtifactStoreID string `json:"artifact_store_id"`
	DeletedAt       string `json:"deleted_at"`
}

func NewWorker(amqpURL string, client storage.Client) (*Worker, error) {
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
		return "artifacthub.jobdeletion.worker"
	}
	return hostname
}

func (w *Worker) Start() {
	log.Printf("JobDeletion Worker: Starting consumer for exchange=%s routing_key=%s", JobDeletionExchange, JobDeletionRoutingKey)
	go w.consumer.Start(w.amqpOptions, w.handleMessage)
}

func (w *Worker) Stop() {
	w.consumer.Stop()
}

func (w *Worker) handleMessage(delivery tackle.Delivery) error {
	log.Printf("JobDeletion Worker: Received a message")

	var event JobDeletionEvent

	err := json.Unmarshal(delivery.Body(), &event)
	if err != nil {
		log.Printf("JobDeletion Worker: Failed to parse message: %s, error: %+v", delivery.Body(), err)
		return err
	}

	log.Printf("JobDeletion Worker: Received job deletion event - JobID=%s, OrgID=%s, ProjectID=%s, ArtifactStoreID=%s, DeletedAt=%s",
		event.JobID,
		event.OrganizationID,
		event.ProjectID,
		event.ArtifactStoreID,
		event.DeletedAt,
	)

	// Delete job artifacts from all artifact buckets
	err = w.deleteJobArtifacts(event.ArtifactStoreID, event.ProjectID, event.JobID)
	if err != nil {
		log.Printf("JobDeletion Worker: Failed to delete artifacts for JobID=%s: %v", event.JobID, err)
		return err
	}

	log.Printf("JobDeletion Worker: Successfully processed job deletion for JobID=%s", event.JobID)
	return nil
}

func (w *Worker) deleteJobArtifacts(artifactStoreID, projectID, jobID string) error {
	// Construct the path for job artifacts
	jobPath := fmt.Sprintf("artifacts/jobs/%s/", jobID)

	log.Printf("JobDeletion Worker: Deleting artifacts at path: %s for ArtifactStoreID=%s", jobPath, artifactStoreID)

	bucketName := artifactStoreID
	idempotencyToken := projectID

	bucket := w.storageClient.GetBucket(storage.BucketOptions{
		Name:       bucketName,
		PathPrefix: idempotencyToken,
	})

	err := bucket.DeletePath(context.Background(), jobPath)
	if err != nil {
		log.Printf("JobDeletion Worker: Error deleting artifacts at path %s: %v", jobPath, err)
		return err
	}

	log.Printf("JobDeletion Worker: Successfully deleted artifacts at path: %s", jobPath)
	return nil
}
