package jobdeletion

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"time"

	tackle "github.com/renderedtext/go-tackle"
	"github.com/renderedtext/go-watchman"
	"github.com/semaphoreio/semaphore/loghub2/pkg/storage"
)

const (
	JobDeletionExchange    = "artifacthub.job_deletion"
	JobDeletionServiceName = "loghub2.job_deletion.worker"
	JobDeletionRoutingKey  = "job.deleted"
)

type JobDeletedEvent struct {
	JobID          string `json:"job_id"`
	OrganizationID string `json:"organization_id"`
	ProjectID      string `json:"project_id"`
}

type Worker struct {
	amqpOptions  *tackle.Options
	consumer     *tackle.Consumer
	redisStorage *storage.RedisStorage
	cloudStorage storage.Storage
}

func NewWorker(amqpURL string, redisStorage *storage.RedisStorage, cloudStorage storage.Storage) (*Worker, error) {
	options := &tackle.Options{
		URL:            amqpURL,
		ConnectionName: workerConnName(),
		RemoteExchange: JobDeletionExchange,
		Service:        JobDeletionServiceName,
		RoutingKey:     JobDeletionRoutingKey,
	}

	consumer := tackle.NewConsumer()

	return &Worker{
		consumer:     consumer,
		amqpOptions:  options,
		redisStorage: redisStorage,
		cloudStorage: cloudStorage,
	}, nil
}

func workerConnName() string {
	hostname := os.Getenv("HOSTNAME")
	if hostname == "" {
		return "loghub2.job_deletion.worker"
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
	defer watchman.Benchmark(time.Now(), "jobdeletion.worker.handle_duration")

	// DEBUG_LOG
	log.Printf("DELETION_DEBUG: Received message: %s", delivery.Body())

	event, err := parseJobDeletedEvent(delivery.Body())
	if err != nil {
		// DEBUG_LOG
		log.Printf("DELETION_DEBUG: Failed to parse message, err=%+v", err)
		log.Printf("JobDeletion: failed to parse message %s err %+v", delivery.Body(), err)
		_ = watchman.Increment("jobdeletion.worker.parse_error")
		return err
	}

	// DEBUG_LOG
	log.Printf("DELETION_DEBUG: Parsed event - job_id=%s, org_id=%s, project_id=%s",
		event.JobID, event.OrganizationID, event.ProjectID)

	log.Printf("JobDeletion: received event for job_id=%s org_id=%s project_id=%s",
		event.JobID, event.OrganizationID, event.ProjectID)

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	errors := []error{}

	// DEBUG_LOG
	log.Printf("DELETION_DEBUG: Attempting to delete from Redis for job_id=%s", event.JobID)

	redisDeleted, err := w.redisStorage.DeleteLogs(ctx, event.JobID)
	if err != nil {
		// DEBUG_LOG
		log.Printf("DELETION_DEBUG: Redis deletion failed, err=%+v", err)
		log.Printf("JobDeletion: failed to delete from Redis job_id=%s err=%+v", event.JobID, err)
		_ = watchman.Increment("jobdeletion.worker.redis_delete_error")
		errors = append(errors, err)
	} else {
		// DEBUG_LOG
		log.Printf("DELETION_DEBUG: Redis deletion succeeded, deleted %d entries", redisDeleted)
		log.Printf("JobDeletion: deleted %d log entries from Redis for job_id=%s", redisDeleted, event.JobID)
		_ = watchman.Increment("jobdeletion.worker.redis_delete_success")
	}

	// DEBUG_LOG
	log.Printf("DELETION_DEBUG: Attempting to delete plain file from cloud storage, filename=%s", event.JobID)

	err = w.cloudStorage.DeleteFile(ctx, event.JobID)
	if err != nil {
		// DEBUG_LOG
		log.Printf("DELETION_DEBUG: Plain file deletion failed, err=%+v", err)
		log.Printf("JobDeletion: failed to delete plain file from cloud storage job_id=%s err=%+v",
			event.JobID, err)
		errors = append(errors, err)
	} else {
		// DEBUG_LOG
		log.Printf("DELETION_DEBUG: Plain file deletion succeeded")
		log.Printf("JobDeletion: deleted plain log file from cloud storage for job_id=%s", event.JobID)
	}

	gzFileName := event.JobID + ".gz"

	// DEBUG_LOG
	log.Printf("DELETION_DEBUG: Attempting to delete compressed file from cloud storage, filename=%s", gzFileName)

	err = w.cloudStorage.DeleteFile(ctx, gzFileName)
	if err != nil {
		// DEBUG_LOG
		log.Printf("DELETION_DEBUG: Compressed file deletion failed, err=%+v", err)
		log.Printf("JobDeletion: failed to delete compressed file from cloud storage job_id=%s err=%+v",
			gzFileName, err)
		errors = append(errors, err)
	} else {
		// DEBUG_LOG
		log.Printf("DELETION_DEBUG: Compressed file deletion succeeded")
		log.Printf("JobDeletion: deleted compressed log file from cloud storage for job_id=%s", gzFileName)
	}

	_ = watchman.Increment("jobdeletion.worker.processed")

	if len(errors) > 0 {
		// DEBUG_LOG
		log.Printf("DELETION_DEBUG: Deletion completed with %d errors, returning error", len(errors))
		_ = watchman.Increment("jobdeletion.worker.failed")
		log.Printf("JobDeletion FAILED for job_id=%s: %d errors", event.JobID, len(errors))
		return fmt.Errorf("deletion failed with %d errors", len(errors))
	}

	// DEBUG_LOG
	log.Printf("DELETION_DEBUG: All deletions succeeded for job_id=%s", event.JobID)

	_ = watchman.Increment("jobdeletion.worker.success")
	log.Printf("JobDeletion: completed successfully for job_id=%s", event.JobID)
	return nil
}

func parseJobDeletedEvent(raw []byte) (*JobDeletedEvent, error) {
	event := &JobDeletedEvent{}
	err := json.Unmarshal(raw, &event)
	if err != nil {
		return nil, err
	}
	return event, nil
}
