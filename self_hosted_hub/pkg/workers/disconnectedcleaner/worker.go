package disconnectedcleaner

import (
	"context"
	"time"

	"github.com/semaphoreio/semaphore/self_hosted_hub/pkg/amqp"
	database "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/database"
	"github.com/semaphoreio/semaphore/self_hosted_hub/pkg/models"
	log "github.com/sirupsen/logrus"
	"gorm.io/gorm"
)

const DisconnectedCleanerName = "self-hosted-disconnected-agents-cleaner"

func Start(publisher *amqp.Publisher) {
	for {
		Tick(publisher)
		time.Sleep(1 * time.Minute)
	}
}

func Tick(publisher *amqp.Publisher) {
	// The advisory lock makes sure that only one cleaner is working at a time
	_ = database.WithAdvisoryLock(DisconnectedCleanerName, func(db *gorm.DB) error {
		return deleteDisconnectedAgents(db, publisher)
	})
}

func deleteDisconnectedAgents(db *gorm.DB, publisher *amqp.Publisher) error {
	// Find all agents that should be cleaned up in a single query
	type AgentInfo struct {
		ID            string  `gorm:"column:id"`
		AssignedJobID *string `gorm:"column:assigned_job_id"`
	}

	var agents []AgentInfo
	err := db.Raw(`
		SELECT a.id, a.assigned_job_id::text AS assigned_job_id FROM agents AS a
			LEFT JOIN agent_types AS at
				ON at.organization_id = a.organization_id
				AND at.name = a.agent_type_name
			WHERE state = ?
			AND EXTRACT(EPOCH FROM NOW()) > EXTRACT(EPOCH FROM a.disconnected_at) + at.release_name_after
			LIMIT 100
		`, models.AgentStateDisconnected,
	).Scan(&agents).Error

	if err != nil {
		log.Errorf("[%s] Error querying disconnected agents for cleanup: %v", DisconnectedCleanerName, err)
		return err
	}

	if len(agents) == 0 {
		log.Infof("[%s] No agents to delete.", DisconnectedCleanerName)
		return nil
	}

	log.Infof("[%s] Found %d disconnected agents to clean up", DisconnectedCleanerName, len(agents))

	// Process agents and collect IDs to delete
	var idsToDelete []string
	ctx := context.Background()

	for _, agent := range agents {
		// For agents with assigned jobs, handle job finalization first
		if agent.AssignedJobID != nil && *agent.AssignedJobID != "" {
			jobID := *agent.AssignedJobID
			log.Infof("[%s] Disconnected agent %s with job %s is being cleaned, marking job as failed",
				DisconnectedCleanerName, agent.ID, jobID)

			err := publisher.HandleJobFinished(ctx, jobID, "failed")
			if err != nil {
				log.Errorf("[%s] Failed to publish job finalization for job %s: %s",
					DisconnectedCleanerName, jobID, err.Error())
				// Skip deleting this agent since we couldn't finalize the job
				continue
			}
		}

		// Add to the list of IDs to delete
		idsToDelete = append(idsToDelete, agent.ID)
	}

	if len(idsToDelete) == 0 {
		log.Infof("[%s] No agents to delete after processing", DisconnectedCleanerName)
		return nil
	}

	// Delete only the agents we've processed successfully
	log.Infof("[%s] Deleting %d disconnected agents", DisconnectedCleanerName, len(idsToDelete))
	dbExec := db.Exec(`DELETE FROM agents WHERE id IN (?)`, idsToDelete)
	if dbExec.Error != nil {
		log.Errorf("[%s] Error deleting disconnected agents: %v", DisconnectedCleanerName, dbExec.Error)
		return dbExec.Error
	}

	if dbExec.RowsAffected != int64(len(idsToDelete)) {
		log.Errorf("[%s] Fewer agents were deleted than expected: expected %d, got %d",
			DisconnectedCleanerName, len(idsToDelete), dbExec.RowsAffected)
	}

	return nil
}
