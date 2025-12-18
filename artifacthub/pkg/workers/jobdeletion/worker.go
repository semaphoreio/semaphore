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
	// DEBUG_LOG
	log.Printf("DELETION_DEBUG: Received message: %s", delivery.Body())

	event, err := ParseJobDeletedEvent(delivery.Body())
	if err != nil {
		// DEBUG_LOG
		log.Printf("DELETION_DEBUG: Failed to parse message, err=%+v", err)
		log.Printf("JobDeletion: failed to parse message %s err %+v", delivery.Body(), err)
		_ = watchman.Increment("jobdeletion.worker.parse_error")
		return err
	}

	// DEBUG_LOG
	log.Printf("DELETION_DEBUG: Parsed event - job_id=%s, artifact_id=%s, org_id=%s, project_id=%s",
		event.JobID.String(),
		event.ArtifactID.String(),
		event.OrganizationID.String(),
		event.ProjectID.String(),
	)

	log.Printf("JobDeletion: processing job_id=%s artifact_id=%s",
		event.JobID.String(),
		event.ArtifactID.String(),
	)

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	// DEBUG_LOG
	log.Printf("DELETION_DEBUG: Looking up artifact by ID: %s", event.ArtifactID.String())

	artifact, err := models.FindArtifactByID(event.ArtifactID.String())
	if err != nil {
		// DEBUG_LOG
		log.Printf("DELETION_DEBUG: Artifact lookup failed, err=%+v", err)
		log.Printf("JobDeletion: artifact not found artifact_id=%s err=%+v", event.ArtifactID.String(), err)
		_ = watchman.Increment("jobdeletion.worker.artifact_not_found")
		return fmt.Errorf("artifact not found: %w", err)
	}

	// DEBUG_LOG
	log.Printf("DELETION_DEBUG: Found artifact - bucket_name=%s, idempotency_token=%s", artifact.BucketName, artifact.IdempotencyToken)

	err = w.deleteJobArtifactsFromBucket(ctx, artifact, event.JobID)
	if err != nil {
		// DEBUG_LOG
		log.Printf("DELETION_DEBUG: Bucket deletion failed, err=%+v", err)
		log.Printf("JobDeletion FAILED for job_id=%s: %v", event.JobID.String(), err)
		_ = watchman.Increment("jobdeletion.worker.deletion_failed")
		return err
	}

	// DEBUG_LOG
	log.Printf("DELETION_DEBUG: Successfully deleted artifacts from bucket for job_id=%s", event.JobID.String())

	_ = watchman.Increment("jobdeletion.worker.processed")
	_ = watchman.Increment("jobdeletion.worker.deletion_succeeded")

	log.Printf("JobDeletion: completed successfully for job_id=%s artifact_id=%s",
		event.JobID.String(), event.ArtifactID.String())

	return nil
}

func (w *Worker) deleteJobArtifactsFromBucket(ctx context.Context, artifact *models.Artifact, jobID uuid.UUID) error {
	// DEBUG_LOG
	log.Printf("DELETION_DEBUG: Getting bucket - name=%s, path_prefix=%s", artifact.BucketName, artifact.IdempotencyToken)

	bucket := w.client.GetBucket(storage.BucketOptions{
		Name:       artifact.BucketName,
		PathPrefix: artifact.IdempotencyToken,
	})

	jobPath := fmt.Sprintf("artifacts/jobs/%s", jobID.String())

	// DEBUG_LOG
	log.Printf("DELETION_DEBUG: Deleting path from bucket: %s", jobPath)

	err := bucket.DeletePath(ctx, jobPath)
	if err != nil {
		// DEBUG_LOG
		log.Printf("DELETION_DEBUG: DeletePath failed, err=%+v", err)
		return err
	}

	// DEBUG_LOG
	log.Printf("DELETION_DEBUG: DeletePath succeeded for path: %s", jobPath)

	return nil
}
