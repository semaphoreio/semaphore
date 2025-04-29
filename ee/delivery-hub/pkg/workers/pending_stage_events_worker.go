package workers

import (
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/database"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/grpc/actions/messages"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/logging"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/models"
	log "github.com/sirupsen/logrus"
	"gorm.io/gorm"
)

type PendingStageEventsWorker struct {
}

func (w *PendingStageEventsWorker) Start() {
	for {
		err := w.Tick()
		if err != nil {
			log.Errorf("Error processing pending events: %v", err)
		}

		time.Sleep(time.Second)
	}
}

func (w *PendingStageEventsWorker) Tick() error {
	//
	// We need to process each stage with pending events separately.
	// So first, we find all the stages with pending events in their queue.
	//
	stageIDs, err := models.FindStagesWithPendingEvents()
	if err != nil {
		return fmt.Errorf("error listing pending stage events: %v", err)
	}

	//
	// We process each stage individually.
	//
	for _, stageID := range stageIDs {
		err := w.ProcessStage(stageID)
		if err != nil {
			return fmt.Errorf("error processing events for stage %s: %v", stageID, err)
		}
	}

	return nil
}

func (w *PendingStageEventsWorker) ProcessStage(stageID uuid.UUID) error {
	stage, err := models.FindStageByID(stageID)
	if err != nil {
		return fmt.Errorf("error finding stage")
	}

	//
	// For each stage, we are only interested in the oldest pending event.
	//
	event, err := models.FindOldestPendingStageEvent(stageID)
	if err != nil {
		return fmt.Errorf("error listing pending events for stage")
	}

	return w.ProcessEvent(stage, event)
}

func (w *PendingStageEventsWorker) ProcessEvent(stage *models.Stage, event *models.StageEvent) error {
	logger := logging.ForStage(stage)

	//
	// Check if another execution is already in progress.
	// TODO: this could probably be built into the query that we do above.
	//
	_, err := models.FindExecutionInState(event.StageID, []string{
		models.StageExecutionPending,
		models.StageExecutionStarted,
	})

	if err == nil {
		logger.Infof("Another execution is already in progress - skipping %s", event.ID)
		return nil
	}

	//
	// If the stage requires manual approval and none was given yet,
	// we move the event to the waiting-for-approval state.
	//
	if stage.ApprovalRequired && event.ApprovedAt == nil {
		if err := event.UpdateState(models.StageEventWaitingForApproval); err != nil {
			return fmt.Errorf("error update event state: %v", err)
		}

		logger.Infof("Event %s waiting for approval", event.ID)

		return nil
	}

	// TODO: any other conditions must be checked here.

	//
	// If we get here, we can start an execution for this event.
	//
	var execution *models.StageExecution
	err = database.Conn().Transaction(func(tx *gorm.DB) error {
		var err error
		execution, err = models.CreateStageExecutionInTransaction(tx, stage.ID, event.ID)
		if err != nil {
			return fmt.Errorf("error creating stage execution: %v", err)
		}

		logger.Infof("Created stage execution %s", execution.ID)

		if err := event.UpdateStateInTransaction(tx, models.StageEventProcessed); err != nil {
			return fmt.Errorf("error updating event state: %v", err)
		}

		logger.Infof("Stage event %s processed", event.ID)
		return nil
	})

	if err != nil {
		return err
	}

	err = messages.NewExecutionCreatedMessage(stage.CanvasID.String(), execution).Publish()
	if err != nil {
		logging.ForStage(stage).Errorf("failed to publish execution created message: %v", err)
	}

	logging.ForStage(stage).Infof("Started execution %s", execution.ID)
	return nil
}
