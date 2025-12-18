package jobdeletion

import (
	"context"
	"fmt"
	"log"
	"os"
	"time"

	uuid "github.com/satori/go.uuid"
	tackle "github.com/renderedtext/go-tackle"
	"github.com/renderedtext/go-watchman"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/models"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/storage"
)

const (
	JobDeletionExchange = "artifacthub.job_deletion"

	JobDeletionServiceName = "artifacthub.job_deletion.worker"

	JobDeletionRoutingKey = "job.deleted"
)

type Worker struct {
	amqpOptions *tackle.Options
	consumer    *tackle.Consumer
	client      storage.Client
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
		consumer:    consumer,
		amqpOptions: options,
		client:      client,
	}, nil
}

func workerConnName() string {
	hostname := os.Getenv("HOSTNAME")
	if hostname == "" {
		return "artifacthub.job_deletion.worker"
	}
	return hostname
}

func (w *Worker) Start() {
	go w.consumer.Start(w.amqpOptions, w.handleMessage)
}

func (w *Worker) Stop() {
	w.consumer.Stop()
}

func (w *Worker) State() string {
	return w.consumer.State
}

func (w *Worker) handleMessage(delivery tackle.Delivery) error {
	event, err := ParseJobDeletedEvent(delivery.Body())
	if err != nil {
		log.Printf("JobDeletion: failed to parse message %s err %+v", delivery.Body(), err)
		_ = watchman.Increment("jobdeletion.worker.parse_error")
		return err
	}

	log.Printf("JobDeletion: processing job_id=%s artifact_id=%s",
		event.JobID.String(),
		event.ArtifactID.String(),
	)

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	artifact, err := models.FindArtifactByID(event.ArtifactID.String())
	if err != nil {
		log.Printf("JobDeletion: artifact not found artifact_id=%s err=%+v", event.ArtifactID.String(), err)
		_ = watchman.Increment("jobdeletion.worker.artifact_not_found")
		return fmt.Errorf("artifact not found: %w", err)
	}

	err = w.deleteJobArtifactsFromBucket(ctx, artifact, event.JobID)
	if err != nil {
		log.Printf("JobDeletion FAILED for job_id=%s: %v", event.JobID.String(), err)
		_ = watchman.Increment("jobdeletion.worker.deletion_failed")
		return err
	}

	_ = watchman.Increment("jobdeletion.worker.processed")
	_ = watchman.Increment("jobdeletion.worker.deletion_succeeded")

	log.Printf("JobDeletion: completed successfully for job_id=%s artifact_id=%s",
		event.JobID.String(), event.ArtifactID.String())

	return nil
}

func (w *Worker) deleteJobArtifactsFromBucket(ctx context.Context, artifact *models.Artifact, jobID uuid.UUID) error {
	bucket := w.client.GetBucket(storage.BucketOptions{
		Name:       artifact.BucketName,
		PathPrefix: artifact.IdempotencyToken,
	})

	jobPath := fmt.Sprintf("artifacts/jobs/%s", jobID.String())

	err := bucket.DeletePath(ctx, jobPath)
	if err != nil {
		return err
	}

	return nil
}
