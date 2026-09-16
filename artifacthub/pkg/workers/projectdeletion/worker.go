// Package projectdeletion empties a project's artifact storage when the project is
// deleted, and stops that if the project comes back.
//
// Deleting a project used to leave its artifacts in place for the whole 30 day
// window in which it can still be restored, so a deleted project's objects stayed
// in storage for a month after the project was gone.
//
// The trigger is the events projecthub already publishes, not a call it makes, so
// every caller of Project.soft_destroy is covered without a change here. The two
// events are not arbitrated against each other: projecthub refuses to restore a
// project until it has been deleted for an hour, by which time the purge has
// finished and cleared its own mark.
//
// Forward-looking only. The queue and its binding are declared when the consumer
// first starts and project_exchange discards what it cannot route, so projects
// already soft-deleted when this ships keep the old behaviour and are cleaned up by
// the hard destroy at the end of their 30 day window.
package projectdeletion

import (
	"fmt"
	"log"
	"os"
	"sync/atomic"
	"time"

	tackle "github.com/renderedtext/go-tackle"
	"github.com/renderedtext/go-watchman"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/api/descriptors/projecthub"
	privateapi "github.com/semaphoreio/semaphore/artifacthub/pkg/api/private"
	"google.golang.org/protobuf/proto"
)

const (
	ProjectExchange = "project_exchange"

	SoftDeletedServiceName = "artifacthub.projectdeletion.worker"
	SoftDeletedRoutingKey  = "soft_deleted"

	RestoredServiceName = "artifacthub.projectrestore.worker"
	RestoredRoutingKey  = "restored"
)

// event is the part of a project lifecycle message these workers act on.
type event struct {
	projectID string
	orgID     string
}

// Worker consumes one project lifecycle event and applies it to the project's
// artifact storage.
type Worker struct {
	amqpOptions       *tackle.Options
	consumer          *tackle.Consumer
	name              string
	decode            func(body []byte) (event, error)
	apply             func(projectID string) error
	successMetric     string
	failureMetric     string
	reconnectAttempts int

	// Keeps an intentional shutdown out of the consumer_exited counter.
	stopping atomic.Bool
}

// NewSoftDeleteWorker empties the artifact storage of a deleted project.
func NewSoftDeleteWorker(amqpURL string) (*Worker, error) {
	return newWorker(workerConfig{
		amqpURL:       amqpURL,
		name:          "ProjectDeletion",
		service:       SoftDeletedServiceName,
		routingKey:    SoftDeletedRoutingKey,
		decode:        decodeDeleted,
		apply:         privateapi.PurgeArtifactContents,
		successMetric: "retention.project_deleted.success",
		failureMetric: "retention.project_deleted.failure",
	})
}

// NewRestoreWorker stops that emptying when the project is restored. Whatever has
// already been deleted is gone; this protects what the project uploads next.
func NewRestoreWorker(amqpURL string) (*Worker, error) {
	return newWorker(workerConfig{
		amqpURL:       amqpURL,
		name:          "ProjectRestore",
		service:       RestoredServiceName,
		routingKey:    RestoredRoutingKey,
		decode:        decodeRestored,
		apply:         privateapi.CancelArtifactPurge,
		successMetric: "retention.project_restored.success",
		failureMetric: "retention.project_restored.failure",
	})
}

type workerConfig struct {
	amqpURL       string
	name          string
	service       string
	routingKey    string
	decode        func(body []byte) (event, error)
	apply         func(projectID string) error
	successMetric string
	failureMetric string
}

func newWorker(config workerConfig) (*Worker, error) {
	if config.amqpURL == "" {
		return nil, fmt.Errorf("%s worker needs an AMQP URL", config.name)
	}

	options := &tackle.Options{
		URL:            config.amqpURL,
		ConnectionName: workerConnName(config.service),
		RemoteExchange: ProjectExchange,
		Service:        config.service,
		RoutingKey:     config.routingKey,
	}

	// No dead-queue callback: the pinned tackle version has none and bumping it
	// renames queues. The failure counter fires on every attempt including the last,
	// and `<queue>.dead` depth is what to alert on from the broker side.
	return &Worker{
		consumer:      tackle.NewConsumer(),
		amqpOptions:   options,
		name:          config.name,
		decode:        config.decode,
		apply:         config.apply,
		successMetric: config.successMetric,
		failureMetric: config.failureMetric,
	}, nil
}

func decodeDeleted(body []byte) (event, error) {
	message := &projecthub.ProjectDeleted{}
	if err := proto.Unmarshal(body, message); err != nil {
		return event{}, err
	}

	return event{projectID: message.GetProjectId(), orgID: message.GetOrgId()}, nil
}

func decodeRestored(body []byte) (event, error) {
	message := &projecthub.ProjectRestored{}
	if err := proto.Unmarshal(body, message); err != nil {
		return event{}, err
	}

	return event{projectID: message.GetProjectId(), orgID: message.GetOrgId()}, nil
}

func workerConnName(service string) string {
	hostname := os.Getenv("HOSTNAME")
	if hostname == "" {
		return service
	}

	return fmt.Sprintf("%s.%s", hostname, service)
}

func (w *Worker) Start() {
	log.Printf("%s Worker: Starting consumer for exchange=%s routing_key=%s",
		w.name, w.amqpOptions.RemoteExchange, w.amqpOptions.RoutingKey)

	// The loop is for the initial connect only. go-tackle owns reconnection: it
	// stops the consumer on a dropped connection, which is what makes Start return
	// nil, then reconnects itself. Calling Start again here would race that.
	go func() {
		for {
			err := w.consumer.Start(w.amqpOptions, w.handleMessage)
			if err != nil {
				log.Printf("%s Worker: error starting consumer %s", w.name, err)
				w.reconnectAttempts++
				waitTime := min(w.reconnectAttempts*2, 60)
				time.Sleep(time.Duration(waitTime) * time.Second)

				continue
			}

			// A consumer that stops by itself is a queue nobody is draining. Not counted
			// when we asked it to stop, so this does not fire on every deploy.
			if !w.stopping.Load() {
				_ = watchman.Increment("retention.project_lifecycle.consumer_exited")
			}

			log.Printf("%s Worker: consumer returned, go-tackle owns reconnection from here", w.name)

			return
		}
	}()
}

func (w *Worker) Stop() {
	w.stopping.Store(true)
	w.consumer.Stop()
}

// handleMessage applies the event. Returning an error is how the work gets retried:
// tackle redelivers ten times before parking the message in the dead queue, which is
// what carries a purge across a database blip.
func (w *Worker) handleMessage(delivery tackle.Delivery) error {
	e, err := w.decode(delivery.Body())
	if err != nil {
		log.Printf("%s Worker: Failed to parse message: %s, error: %+v", w.name, delivery.Body(), err)
		w.recordFailure()

		return err
	}

	if e.projectID == "" {
		log.Printf("%s Worker: Invalid message, missing projectID", w.name)
		w.recordFailure()

		return fmt.Errorf("invalid message, missing projectID")
	}

	if err := w.apply(e.projectID); err != nil {
		log.Printf("%s Worker: Failed to handle project %s in org %s: %v", w.name, e.projectID, e.orgID, err)
		w.recordFailure()

		return err
	}

	if err := watchman.Increment(w.successMetric); err != nil {
		log.Printf("%s Worker: Failed to increment watchman counter: %v", w.name, err)
	}

	log.Printf("%s Worker: Handled project %s in org %s", w.name, e.projectID, e.orgID)

	return nil
}

func (w *Worker) recordFailure() {
	if err := watchman.Increment(w.failureMetric); err != nil {
		log.Printf("%s Worker: Failed to increment watchman counter: %v", w.name, err)
	}
}
