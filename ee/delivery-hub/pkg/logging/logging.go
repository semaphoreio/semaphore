package logging

import (
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/models"
	log "github.com/sirupsen/logrus"
)

func ForStage(stage *models.Stage) *log.Entry {
	if stage == nil {
		return log.WithFields(log.Fields{})
	}

	return log.WithFields(
		log.Fields{
			"organization_id": stage.OrganizationID,
			"canvas_id":       stage.CanvasID,
			"name":            stage.Name,
		},
	)
}

func ForExecution(execution *models.StageExecution) *log.Entry {
	if execution == nil {
		return log.WithFields(log.Fields{})
	}

	return log.WithFields(
		log.Fields{
			"id":             execution.ID,
			"stage_id":       execution.StageID,
			"stage_event_id": execution.StageEventID,
		},
	)
}

func ForEvent(event *models.Event) *log.Entry {
	if event == nil {
		return log.WithFields(log.Fields{})
	}

	return log.WithFields(
		log.Fields{
			"id":          event.ID,
			"source_id":   event.SourceID,
			"source_type": event.SourceType,
		},
	)
}
