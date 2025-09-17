package disconnectedcleaner

import (
	"time"

	database "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/database"
	"github.com/semaphoreio/semaphore/self_hosted_hub/pkg/models"
	log "github.com/sirupsen/logrus"
	"gorm.io/gorm"
)

const DisconnectedCleanerName = "self-hosted-disconnected-agents-cleaner"

func Start() {
	for {
		Tick()
		time.Sleep(1 * time.Minute)
	}
}

func Tick() {
	// The advisory lock makes sure that only one cleaner is working at a time
	_ = database.WithAdvisoryLock(DisconnectedCleanerName, deleteDisconnectedAgents)
}

func deleteDisconnectedAgents(db *gorm.DB) error {
	var ids []string

	err := db.Raw(`
		SELECT id FROM agents AS a
			LEFT JOIN agent_types AS at
				ON at.organization_id = a.organization_id
				AND at.name = a.agent_type_name
			WHERE state = ?
			AND EXTRACT(EPOCH FROM NOW()) > EXTRACT(EPOCH FROM a.disconnected_at) + at.release_name_after
			LIMIT 100
		`, models.AgentStateDisconnected,
	).Scan(&ids).Error

	if err != nil {
		log.Errorf("Error querying disconnected agents: %v", err)
		return err
	}

	if len(ids) == 0 {
		log.Infof("No agents to delete.")
		return nil
	}

	log.Infof("Deleting agents: %v", ids)
	dbExec := db.Exec(`DELETE FROM agents WHERE id in ?`, ids)
	if dbExec.Error != nil {
		log.Errorf("Error deleting disconnected agents: %v", err)
		return err
	}

	if dbExec.RowsAffected != int64(len(ids)) {
		log.Errorf("More agents were deleted than expected: %v", err)
		return err
	}

	return nil
}
