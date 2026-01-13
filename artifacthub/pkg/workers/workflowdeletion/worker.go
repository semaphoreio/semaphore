package workflowdeletion

import (
	"context"
	"fmt"
	"log"
	"os"
	"time"

	tackle "github.com/renderedtext/go-tackle"
	"github.com/renderedtext/go-watchman"
	plumber_wf "github.com/semaphoreio/semaphore/artifacthub/pkg/api/descriptors/plumber_w_f.workflow"
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
	WorkflowDeletionExchange    = "plumber.workflow_deletion_exchange"
	WorkflowDeletionServiceName = "artifacthub.workflowdeletion.worker"
	WorkflowDeletionRoutingKey  = "deleted"
)

func NewWorker(amqpURL string, client storage.Client) (*Worker, error) {
	options := &tackle.Options{
		URL:            amqpURL,
		ConnectionName: workerConnName(),
		RemoteExchange: WorkflowDeletionExchange,
		Service:        WorkflowDeletionServiceName,
		RoutingKey:     WorkflowDeletionRoutingKey,
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
		return "artifacthub.workflowdeletion.worker"
	}
	return hostname
}

func (w *Worker) Start() {
	log.Printf("WorkflowDeletion Worker: Starting consumer for exchange=%s routing_key=%s", WorkflowDeletionExchange, WorkflowDeletionRoutingKey)
	go func() {
		for {
			err := w.consumer.Start(w.amqpOptions, w.handleMessage)
			if err != nil {
				log.Printf("WorkflowDeletion Worker: error starting consumer %s", err)
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
	event := &plumber_wf.WorkflowDeleted{}

	err := proto.Unmarshal(delivery.Body(), event)
	if err != nil {
		log.Printf("WorkflowDeletion Worker: Failed to parse message: %s, error: %+v", delivery.Body(), err)
		return err
	}

	workflowID := event.GetWorkflowId()
	artifactStoreID := event.GetArtifactStoreId()

	if workflowID == "" {
		log.Printf("WorkflowDeletion Worker: Invalid message, missing workflowID: %+v", event)
		return fmt.Errorf("invalid message, missing workflowID")
	}

	if artifactStoreID == "" {
		log.Printf("WorkflowDeletion Worker: No artifact store for workflow=%s, skipping", workflowID)
		return nil
	}

	artifact, err := models.FindArtifactByID(artifactStoreID)
	if err != nil {
		log.Printf("WorkflowDeletion Worker: Failed to find artifact store with ID=%s: %v", artifactStoreID, err)
		return err
	}

	bucketName := artifact.BucketName
	idempotencyToken := artifact.IdempotencyToken

	workflowPath := fmt.Sprintf("artifacts/workflows/%s/", workflowID)

	bucket := w.storageClient.GetBucket(storage.BucketOptions{
		Name:       bucketName,
		PathPrefix: idempotencyToken,
	})

	err = bucket.DeletePath(context.Background(), workflowPath)
	if err != nil {
		log.Printf("WorkflowDeletion Worker: Error deleting artifacts at path %s: %v", workflowPath, err)
		return err
	}

	err = watchman.Increment("retention.workflow_deleted.success")
	if err != nil {
		log.Printf("WorkflowDeletion Worker: Failed to increment watchman counter: %v", err)
	}

	log.Printf("WorkflowDeletion Worker: Successfully deleted artifacts at path %s for WorkflowID=%s", workflowPath, workflowID)
	return nil
}
