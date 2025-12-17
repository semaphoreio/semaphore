package jobdeletion

import (
	"log"
	"os"

	tackle "github.com/renderedtext/go-tackle"
	"github.com/renderedtext/go-watchman"
)

const (
	JobDeletionExchange = "artifacthub.job_deletion"

	JobDeletionServiceName = "artifacthub.job_deletion.worker"

	JobDeletionRoutingKey = "job.deleted"
)

// Worker handles job deletion events from zebra
type Worker struct {
	amqpOptions *tackle.Options
	consumer    *tackle.Consumer
}

// NewWorker creates a new job deletion worker
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
		return "artifacthub.job_deletion.worker"
	}
	return hostname
}

func (w *Worker) Start() {
	go w.consumer.Start(w.amqpOptions, w.handleMessage)
}

// Stop stops the consumer
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

	log.Printf("JobDeletion: received event for job_id=%s org_id=%s project_id=%s",
		event.JobID.String(),
		event.OrganizationID.String(),
		event.ProjectID.String(),
	)

	_ = watchman.Increment("jobdeletion.worker.processed")

	return nil
}
