package workers

import (
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/database"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/models"
	pb "github.com/semaphoreio/semaphore/delivery-hub/pkg/protos/delivery"
	log "github.com/sirupsen/logrus"
	"gorm.io/gorm"
)

type PendingEventsWorker struct{}

func (w *PendingEventsWorker) Start() {
	for {
		err := w.Tick()
		if err != nil {
			log.Errorf("Error processing pending events: %v", err)
		}

		time.Sleep(time.Second)
	}
}

func (w *PendingEventsWorker) Tick() error {
	events, err := models.ListPendingEvents()
	if err != nil {
		log.Errorf("Error listing pending events: %v", err)
		return err
	}

	for _, event := range events {
		err := w.ProcessEvent(&event)
		if err != nil {
			log.Errorf("Error processing pending event %s: %v", event.ID, err)
		}
	}

	return nil
}

func (w *PendingEventsWorker) ProcessEvent(event *models.Event) error {
	//
	// TODO
	// Not yet sure if events emitted for stage executions will be consumed here too.
	// So, for now, this only consumes events coming from 'real' event sources.
	//

	connections, err := models.ListConnectionsForSource(
		event.SourceID,
		pb.Connection_TYPE_EVENT_SOURCE.String(),
	)

	if err != nil {
		return fmt.Errorf("error listing connections for source %s: %v", event.SourceID, err)
	}

	//
	// If the source is not connected to any stage, we discard the event.
	//
	if len(connections) == 0 {
		err := event.Discard()
		if err != nil {
			return fmt.Errorf("error discarding event %s: %v", event.ID.String(), err)
		}

		return nil
	}

	//
	// Otherwise, we find all the stages, apply their filters on this event.
	//
	stages, err := models.ListStagesByIDs(w.stageIDs(connections))
	if err != nil {
		return fmt.Errorf("error listing stages for source %s: %v", event.SourceID, err)
	}

	stages, err = w.filterStages(event, stages)
	if err != nil {
		return fmt.Errorf("error applying filters on stages")
	}

	//
	// If after applying the filters,
	// we realize this event shouldn't go to any stage,
	// we mark it as processed, and return.
	//
	if len(stages) == 0 {
		err := event.MarkAsProcessed()
		if err != nil {
			return fmt.Errorf("error discarding event %s: %v", event.ID.String(), err)
		}

		return nil
	}

	return w.enqueueEvent(event, stages)
}

func (w *PendingEventsWorker) filterStages(event *models.Event, stages []models.Stage) ([]models.Stage, error) {
	//
	// TODO
	// Here is where we would apply the stage filters, but we still don't have them.
	// Stage filters prevent events from entering the stage queue.
	//
	// For POC purposes, all events enter the queue.
	//
	return stages, nil
}

func (w *PendingEventsWorker) enqueueEvent(event *models.Event, stages []models.Stage) error {
	return database.Conn().Transaction(func(tx *gorm.DB) error {
		for _, stage := range stages {
			_, err := models.CreateStageEventInTransaction(tx, stage.ID, event.SourceID)
			if err != nil {
				return fmt.Errorf("error creating pending stage event: %v", err)
			}
		}

		if err := event.MarkAsProcessedInTransaction(tx); err != nil {
			return fmt.Errorf("error enqueueing event %s: %v", event.ID, err)
		}

		return nil
	})
}

func (w *PendingEventsWorker) stageIDs(connections []models.StageConnection) []uuid.UUID {
	IDs := []uuid.UUID{}
	for _, c := range connections {
		IDs = append(IDs, c.StageID)
	}

	return IDs
}
