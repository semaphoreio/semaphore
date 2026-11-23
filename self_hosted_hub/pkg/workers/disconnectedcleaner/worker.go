package disconnectedcleaner

import (
	"time"

	database "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/database"
	"github.com/semaphoreio/semaphore/self_hosted_hub/pkg/models"
	log "github.com/sirupsen/logrus"
	"gorm.io/gorm"
)

const DisconnectedCleanerName = "self-hosted-disconnected-agents-cleaner"
const batchSize = 100

// Bounds how long a tick can take when many names are released at once.
const maxBatchesPerTick = 10

func Start() {
	for {
		Tick()
		time.Sleep(1 * time.Minute)
	}
}

func Tick() {
	for i := 0; i < maxBatchesPerTick; i++ {
		deleted := 0

		// The advisory lock makes sure that only one cleaner is working at a time
		err := database.WithAdvisoryLock(DisconnectedCleanerName, func(db *gorm.DB) error {
			var err error
			deleted, err = deleteDisconnectedAgents(db)
			return err
		})

		if err != nil || deleted < batchSize {
			return
		}
	}

	log.Warnf("Reached the limit of %d batches in a tick, remaining agents are left for the next one", maxBatchesPerTick)
}

func deleteDisconnectedAgents(db *gorm.DB) (int, error) {
	var ids []string

	err := db.Raw(`
		SELECT id FROM agents AS a
			LEFT JOIN agent_types AS at
				ON at.organization_id = a.organization_id
				AND at.name = a.agent_type_name
			WHERE state = ?
			AND EXTRACT(EPOCH FROM NOW()) > EXTRACT(EPOCH FROM a.disconnected_at) + at.release_name_after
			ORDER BY a.disconnected_at ASC
			LIMIT ?
		`, models.AgentStateDisconnected, batchSize,
	).Scan(&ids).Error

	if err != nil {
		log.Errorf("Error querying disconnected agents: %v", err)
		return 0, err
	}

	if len(ids) == 0 {
		log.Infof("No agents to delete.")
		return 0, nil
	}

	log.Infof("Deleting agents: %v", ids)
	dbExec := db.Exec(`DELETE FROM agents WHERE id in ?`, ids)
	if dbExec.Error != nil {
		log.Errorf("Error deleting disconnected agents: %v", dbExec.Error)
		return 0, dbExec.Error
	}

	if dbExec.RowsAffected != int64(len(ids)) {
		log.Errorf("Expected to delete %d disconnected agents, deleted %d", len(ids), dbExec.RowsAffected)
	}

	return len(ids), nil
}
