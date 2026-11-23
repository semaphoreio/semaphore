package agentcleaner

import (
	"context"
	"os"
	"time"

	log "github.com/sirupsen/logrus"

	database "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/database"
	models "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/models"
	"gorm.io/gorm"
)

const CleanerName = "self-hosted-agents-cleaner"
const batchSize = 100

// Bounds the callbacks published in one tick when a backlog has built up.
const maxBatchesPerTick = 10

type jobFinisher interface {
	HandleJobFinished(ctx context.Context, jobID string, result string) error
}

func Start(publisher jobFinisher) {
	initialDelay()
	for {
		Tick(publisher)
		time.Sleep(1 * time.Minute)
	}
}

func Tick(publisher jobFinisher) {
	for i := 0; i < maxBatchesPerTick; i++ {
		found, deleted := 0, 0

		// The advisory lock makes sure that only one cleaner is working at a time
		err := database.WithAdvisoryLock(CleanerName, func(db *gorm.DB) error {
			var err error
			found, deleted, err = deleteStuckAgents(db, publisher)
			return err
		})

		// A batch that deleted nothing would be selected again, so it ends the tick.
		if err != nil || found < batchSize || deleted == 0 {
			return
		}
	}
}

func deleteStuckAgents(db *gorm.DB, publisher jobFinisher) (int, int, error) {
	oneMinAgo := time.Now().Add(-1 * time.Minute)
	threeMinsAgo := time.Now().Add(-3 * time.Minute)
	fifteenMinsAgo := time.Now().Add(-15 * time.Minute)

	// Find all agents that should be cleaned up in a single query
	type AgentInfo struct {
		ID            string     `gorm:"column:id"`
		AssignedJobID *string    `gorm:"column:assigned_job_id"`
		JobFinishedAt *time.Time `gorm:"column:job_finished_at"`
	}

	var agents []AgentInfo
	err := db.Model(&models.Agent{}).
		Select("id, assigned_job_id::text as assigned_job_id, job_finished_at").
		Where("state = ? OR assigned_job_id IS NOT NULL", models.AgentStateRegistered).
		Where(
			"(last_sync_at IS NULL AND created_at < ?) OR (last_sync_at < ? AND assigned_job_id IS NULL) OR (last_sync_at < ?)",
			oneMinAgo, threeMinsAgo, fifteenMinsAgo,
		).
		Order("last_sync_at ASC NULLS FIRST").
		Limit(batchSize).
		Scan(&agents).Error

	if err != nil {
		log.Printf("[%s] Error while querying agents for cleanup: %s", CleanerName, err.Error())
		return 0, 0, err
	}

	if len(agents) == 0 {
		log.Printf("[%s] No agents to clean up", CleanerName)
		return 0, 0, nil
	}

	log.Printf("[%s] Found %d agents to clean up", CleanerName, len(agents))

	// Process agents and collect IDs to delete
	var idsToDelete []string
	ctx := context.Background()

	for _, agent := range agents {
		// For agents with assigned jobs, handle job finalization first,
		// unless the finished callback of the job was already published.
		if agent.AssignedJobID != nil && agent.JobFinishedAt == nil {
			jobID := *agent.AssignedJobID
			log.Printf("[%s] Agent %s with job %s is being cleaned, marking job as failed", CleanerName, agent.ID, jobID)

			err := publisher.HandleJobFinished(ctx, jobID, "failed")
			if err != nil {
				log.Printf("[%s] Failed to publish job finalization for job %s: %s", CleanerName, jobID, err.Error())
				// Skip deleting this agent since we couldn't finalize the job
				continue
			}
		}

		// Add to the list of IDs to delete
		idsToDelete = append(idsToDelete, agent.ID)
	}

	if len(idsToDelete) == 0 {
		log.Printf("[%s] No agents to delete after processing", CleanerName)
		return len(agents), 0, nil
	}

	// Delete only the agents we've processed successfully
	log.Printf("[%s] Deleting %d agents", CleanerName, len(idsToDelete))
	err = db.Where("id IN (?)", idsToDelete).Delete(&models.Agent{}).Error
	if err != nil {
		log.Printf("[%s] Error while deleting agents: %s", CleanerName, err.Error())
		return len(agents), 0, err
	}

	return len(agents), len(idsToDelete), nil
}

func initialDelay() {
	delayInterval := os.Getenv("AGENT_CLEANER_INITIAL_DELAY")
	if delayInterval == "" {
		return
	}
	interval, err := time.ParseDuration(delayInterval)
	if err != nil {
		log.Printf("[%s] Error while parsing initial delay interval '%s': %v", CleanerName, delayInterval, err)
		return
	}
	time.Sleep(interval)
}
