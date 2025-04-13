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
