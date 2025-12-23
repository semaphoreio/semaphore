package jobdeletion

import (
	"encoding/json"
	"log"
	"os"

	tackle "github.com/renderedtext/go-tackle"
)

type Worker struct {
	amqpOptions *tackle.Options
	consumer    *tackle.Consumer
}

const (
	JobDeletionExchange    = "job_deletion_exchange"
	JobDeletionServiceName = "artifacthub.jobdeletion.worker"
	JobDeletionRoutingKey  = "job.deleted"
)

type JobDeletionEvent struct {
	JobID          string `json:"job_id"`
	OrganizationID string `json:"organization_id"`
	ProjectID      string `json:"project_id"`
	DeletedAt      string `json:"deleted_at"`
}

func NewWorker(amqpURL string) (*Worker, error) {
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

	log.Printf("JobDeletion Worker: Received job deletion event - JobID=%s, OrgID=%s, ProjectID=%s, DeletedAt=%s",
		event.JobID,
		event.OrganizationID,
		event.ProjectID,
		event.DeletedAt,
	)

	// TODO: Implement actual cleanup logic here after messaging test

	log.Printf("JobDeletion Worker: Successfully processed job deletion for JobID=%s", event.JobID)
	return nil
}
