package pipelinedeletion

import (
	"context"
	"fmt"
	"log"
	"os"
	"time"

	tackle "github.com/renderedtext/go-tackle"
	"github.com/renderedtext/go-watchman"
	plumber_pipeline "github.com/semaphoreio/semaphore/artifacthub/pkg/api/descriptors/plumber.pipeline"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/models"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/storage"
	"google.golang.org/protobuf/proto"
)

type Worker struct {
	amqpOptions       *tackle.Options
	consumer          *tackle.Consumer
	storageClient     storage.Client
	reconnectAttempts int
}

const (
	PipelineDeletionExchange    = "plumber.pipeline_deletion_exchange"
	PipelineDeletionServiceName = "artifacthub.pipelinedeletion.worker"
	PipelineDeletionRoutingKey  = "deleted"
)

func NewWorker(amqpURL string, client storage.Client) (*Worker, error) {
	options := &tackle.Options{
		URL:            amqpURL,
		ConnectionName: workerConnName(),
		RemoteExchange: PipelineDeletionExchange,
		Service:        PipelineDeletionServiceName,
		RoutingKey:     PipelineDeletionRoutingKey,
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
		return "artifacthub.pipelinedeletion.worker"
	}
	return hostname
}

func (w *Worker) Start() {
	log.Printf("PipelineDeletion Worker: Starting consumer for exchange=%s routing_key=%s", PipelineDeletionExchange, PipelineDeletionRoutingKey)
	go func() {
		for {
			err := w.consumer.Start(w.amqpOptions, w.handleMessage)
			if err != nil {
				log.Printf("PipelineDeletion Worker: error starting consumer %s", err)
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
	event := &plumber_pipeline.PipelineDeleted{}

	err := proto.Unmarshal(delivery.Body(), event)
	if err != nil {
		log.Printf("PipelineDeletion Worker: Failed to parse message: %s, error: %+v", delivery.Body(), err)
		return err
	}

	pipelineID := event.GetPipelineId()
	artifactStoreID := event.GetArtifactStoreId()

	if pipelineID == "" {
		log.Printf("PipelineDeletion Worker: Invalid message, missing pipelineID: %+v", event)
		return fmt.Errorf("invalid message, missing pipelineID")
	}

	if artifactStoreID == "" {
		log.Printf("PipelineDeletion Worker: No artifact store for pipeline=%s, skipping", pipelineID)
		return nil
	}

	artifact, err := models.FindArtifactByID(artifactStoreID)
	if err != nil {
		log.Printf("PipelineDeletion Worker: Failed to find artifact store with ID=%s: %v", artifactStoreID, err)
		return err
	}

	bucketName := artifact.BucketName
	idempotencyToken := artifact.IdempotencyToken

	pipelinePath := fmt.Sprintf("artifacts/pipelines/%s/", pipelineID)

	bucket := w.storageClient.GetBucket(storage.BucketOptions{
		Name:       bucketName,
		PathPrefix: idempotencyToken,
	})

	err = bucket.DeletePath(context.Background(), pipelinePath)
	if err != nil {
		log.Printf("PipelineDeletion Worker: Error deleting artifacts at path %s: %v", pipelinePath, err)
		return err
	}

	err = watchman.Increment("retention.pipeline_deleted.success")
	if err != nil {
		log.Printf("PipelineDeletion Worker: Failed to increment watchman counter: %v", err)
	}

	log.Printf("PipelineDeletion Worker: Successfully deleted artifacts at path %s for PipelineID=%s", pipelinePath, pipelineID)
	return nil
}
