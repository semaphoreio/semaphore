package jobdeleter

import (
	"context"
	"fmt"
	"log"
	"os"
	"time"

	tackle "github.com/renderedtext/go-tackle"
	watchman "github.com/renderedtext/go-watchman"

	privateapi "github.com/semaphoreio/semaphore/artifacthub/pkg/api/private"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/storage"
)

// Config lists the AMQP parameters required to bind the consumer.
type Config struct {
	Exchange   string
	RoutingKey string
	Service    string
}

// Worker listens for job deletion events and removes the corresponding files
// from Artifacthub storage.
type Worker struct {
	amqpOptions *tackle.Options
	consumer    *tackle.Consumer
	deletePath  func(ctx context.Context, artifactID, path string) error
}

// NewWorker creates a worker that consumes events from the configured queue.
func NewWorker(amqpURL string, cfg Config, storageClient storage.Client) (*Worker, error) {
	if cfg.Exchange == "" {
		return nil, fmt.Errorf("jobdeleter: exchange must be configured")
	}

	if cfg.RoutingKey == "" {
		return nil, fmt.Errorf("jobdeleter: routing key must be configured")
	}

	if cfg.Service == "" {
		return nil, fmt.Errorf("jobdeleter: service must be configured")
	}

	options := &tackle.Options{
		URL:            amqpURL,
		ConnectionName: workerConnName(),
		RemoteExchange: cfg.Exchange,
		Service:        cfg.Service,
		RoutingKey:     cfg.RoutingKey,
	}

	return &Worker{
		amqpOptions: options,
		consumer:    tackle.NewConsumer(),
		deletePath: func(ctx context.Context, artifactID, path string) error {
			return privateapi.DeleteArtifactPath(ctx, storageClient, artifactID, path)
		},
	}, nil
}

func workerConnName() string {
	hostname := os.Getenv("HOSTNAME")
	if hostname == "" {
		return "artifacthub.jobdeleter.worker"
	}

	return hostname
}

// Start begins consuming job deletion messages.
func (w *Worker) Start() {
	go w.consumer.Start(w.amqpOptions, w.handleMessage)
}

// Stop halts the worker consumer.
func (w *Worker) Stop() {
	w.consumer.Stop()
}

func (w *Worker) handleMessage(delivery tackle.Delivery) error {
	return w.processMessage(delivery.Body())
}

func (w *Worker) processMessage(payload []byte) error {
	msg, err := ParseMessage(payload)
	if err != nil {
		log.Printf("JobDeleter: invalid message: %v", err)
		return err
	}

	path := fmt.Sprintf("artifacts/jobs/%s/", msg.JobID)

	ctx, cancel := context.WithTimeout(context.Background(), time.Minute)
	defer cancel()

	defer watchman.BenchmarkWithTags(time.Now(), "jobdeleter.worker.delete_duration", []string{msg.ArtifactID})
	err = w.deletePath(ctx, msg.ArtifactID, path)

	if err != nil {
		_ = watchman.Increment("jobdeleter.worker.failure")
		log.Printf("JobDeleter: failed deleting artifacts job_id=%s artifact_id=%s err=%v", msg.JobID, msg.ArtifactID, err)
		return err
	}

	_ = watchman.Increment("jobdeleter.worker.success")
	log.Printf("JobDeleter: deleted job artifacts job_id=%s artifact_id=%s", msg.JobID, msg.ArtifactID)

	return nil
}
