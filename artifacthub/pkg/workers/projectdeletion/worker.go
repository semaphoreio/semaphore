// Package projectdeletion marks a project's artifact storage for purging when the
// project is soft-deleted, and clears the mark when it is restored. The two events come
// on separate queues, so the handlers compare event times and a restore wins either way round.
package projectdeletion

import (
	"fmt"
	"log"
	"os"
	"time"

	tackle "github.com/renderedtext/go-tackle"
	"github.com/renderedtext/go-watchman"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/api/descriptors/projecthub"
	privateapi "github.com/semaphoreio/semaphore/artifacthub/pkg/api/private"
	"google.golang.org/protobuf/proto"
	"google.golang.org/protobuf/types/known/timestamppb"
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
	at        time.Time
}

// Worker consumes one project lifecycle event and applies it to the project's
// artifact storage.
type Worker struct {
	amqpOptions       *tackle.Options
	consumer          *tackle.Consumer
	name              string
	decode            func(body []byte) (event, error)
	apply             func(projectID string, at time.Time) error
	successMetric     string
	failureMetric     string
	reconnectAttempts int
}

// NewSoftDeleteWorker marks a deleted project's artifact storage to be emptied once
// the grace period is up.
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

// NewRestoreWorker cancels that when the project is restored, so a restore inside the
// grace period brings the artifacts back. Anything already emptied stays gone.
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
	apply         func(projectID string, at time.Time) error
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

	return event{projectID: message.GetProjectId(), orgID: message.GetOrgId(), at: eventTime(message.GetTimestamp())}, nil
}

func decodeRestored(body []byte) (event, error) {
	message := &projecthub.ProjectRestored{}
	if err := proto.Unmarshal(body, message); err != nil {
		return event{}, err
	}

	return event{projectID: message.GetProjectId(), orgID: message.GetOrgId(), at: eventTime(message.GetTimestamp())}, nil
}

// eventTime is when the change happened, at the whole-second precision it is published
// with, so a delete and a restore in the same second tie and the restore wins.
func eventTime(ts *timestamppb.Timestamp) time.Time {
	if ts == nil || ts.GetSeconds() == 0 {
		return time.Now().UTC().Truncate(time.Second)
	}

	return ts.AsTime().UTC().Truncate(time.Second)
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

			log.Printf("%s Worker: consumer returned, go-tackle owns reconnection from here", w.name)

			return
		}
	}()
}

func (w *Worker) Stop() {
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

	if err := w.apply(e.projectID, e.at); err != nil {
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
