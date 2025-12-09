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

	log.Printf("JobDeletion: processing job_id=%s org_id=%s project_id=%s",
		event.JobID.String(),
		event.OrganizationID.String(),
		event.ProjectID.String(),
	)

	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	deletedCount := 0
	errors := []error{}

	artifact, err := models.FindArtifactByIdempotencyToken(event.OrganizationID.String())
	if err == nil {
		err = w.deleteJobArtifactsFromBucket(ctx, artifact, event.JobID)
		if err != nil {
			log.Printf("Failed to delete from org bucket: %v", err)
			errors = append(errors, err)
		} else {
			deletedCount++
		}
	}

	buckets := []string{}
	err = models.IterAllBuckets(func(bucketName string) {
		buckets = append(buckets, bucketName)
	})
	if err != nil {
		log.Printf("Failed to list buckets: %v", err)
		errors = append(errors, err)
		_ = watchman.Increment("jobdeletion.worker.bucket_list_error")
		return fmt.Errorf("failed to list buckets: %w", err)
	}

	for _, bucketName := range buckets {
		artifact, err := models.FindByBucketName(bucketName)
		if err != nil {
			continue
		}

		err = w.deleteJobArtifactsFromBucket(ctx, &artifact, event.JobID)
		if err != nil {
			log.Printf("Failed to delete from bucket %s: %v", bucketName, err)
			errors = append(errors, err)
		} else {
			deletedCount++
		}
	}

	_ = watchman.Increment("jobdeletion.worker.processed")
	_ = watchman.IncrementBy("jobdeletion.worker.buckets_checked", len(buckets))
	_ = watchman.IncrementBy("jobdeletion.worker.deletions_succeeded", deletedCount)

	if len(errors) > 0 {
		_ = watchman.IncrementBy("jobdeletion.worker.deletions_failed", len(errors))
		log.Printf("JobDeletion FAILED for job_id=%s: %d errors", event.JobID.String(), len(errors))
		return fmt.Errorf("deletion failed with %d errors", len(errors))
	}

	log.Printf("JobDeletion: completed successfully for job_id=%s deleted_from=%d buckets",
		event.JobID.String(), deletedCount)

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
