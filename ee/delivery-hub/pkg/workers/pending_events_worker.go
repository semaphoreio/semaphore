package workers

import (
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/database"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/logging"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/models"
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
		e := event
		logger := logging.ForEvent(&event)
		err := w.ProcessEvent(logger, &e)
		if err != nil {
			logger.Errorf("Error processing pending event: %v", err)
		}
	}

	return nil
}

func (w *PendingEventsWorker) ProcessEvent(logger *log.Entry, event *models.Event) error {
	logger.Info("Processing")

	connections, err := models.ListConnectionsForSource(
		event.SourceID,
		event.SourceType,
	)

	if err != nil {
		return fmt.Errorf("error listing connections: %v", err)
	}

	//
	// If the source is not connected to any stage, we discard the event.
	//
	if len(connections) == 0 {
		logger.Info("Unconnected source - discarding")
		err := event.Discard()
		if err != nil {
			return fmt.Errorf("error discarding event: %v", err)
		}

		return nil
	}

	//
	// Otherwise, we find all the stages, apply their filters on this event.
	//
	stageIDs := w.stageIDsFromConnections(connections)
	stages, err := models.ListStagesByIDs(stageIDs)
	if err != nil {
		return fmt.Errorf("error listing stages: %v", err)
	}

	logger.Infof("Connected stages: %v", stageIDs)

	stages, err = w.filterStages(event, stages)
	if err != nil {
		return fmt.Errorf("error applying filters")
	}

	//
	// If after applying the filters,
	// we realize this event shouldn't go to any stage,
	// we mark it as processed, and return.
	//
	if len(stages) == 0 {
		logger.Info("No connections after filtering")
		err := event.MarkAsProcessed()
		if err != nil {
			return fmt.Errorf("error discarding event: %v", err)
		}

		return nil
	}

	err = w.enqueueEvent(event, stages)
	if err != nil {
		return err
	}

	log.Infof("Stages after filtering: %v", w.idsFromStages(stages))
	return nil
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

func (w *PendingEventsWorker) stageIDsFromConnections(connections []models.StageConnection) []uuid.UUID {
	IDs := []uuid.UUID{}
	for _, c := range connections {
		IDs = append(IDs, c.StageID)
	}

	return IDs
}

func (w *PendingEventsWorker) idsFromStages(stages []models.Stage) []uuid.UUID {
	IDs := []uuid.UUID{}
	for _, s := range stages {
		IDs = append(IDs, s.ID)
	}

	return IDs
}
