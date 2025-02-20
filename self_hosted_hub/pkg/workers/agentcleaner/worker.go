package agentcleaner

import (
	"os"
	"time"

	log "github.com/sirupsen/logrus"

	database "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/database"
	models "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/models"
	"gorm.io/gorm"
)

const CleanerName = "self-hosted-agents-cleaner"

func Start() {
	initialDelay()
	for {
		Tick()
		time.Sleep(1 * time.Minute)
	}
}

func Tick() {
	// The advisory lock makes sure that only one cleaner is working at a time
	_ = database.WithAdvisoryLock(CleanerName, deleteStuckAgents)
}

func deleteStuckAgents(db *gorm.DB) error {
	oneMinAgo := time.Now().Add(-1 * time.Minute)
	threeMinsAgo := time.Now().Add(-3 * time.Minute)
	fifteenMinsAgo := time.Now().Add(-15 * time.Minute)

	err := db.Where("last_sync_at IS NULL AND created_at < ?", oneMinAgo).
		Or(db.Where("last_sync_at < ? AND assigned_job_id IS NULL", threeMinsAgo)).
		Or(db.Where("last_sync_at < ?", fifteenMinsAgo)).
		Delete(models.Agent{}).
		Error

	if err != nil {
		log.Printf("error while deleting stuck agents, err: %s", err.Error())
	}

	return err
}

func initialDelay() {
	delayInterval := os.Getenv("AGENT_CLEANER_INITIAL_DELAY")
	if delayInterval == "" {
		return
	}
	interval, err := time.ParseDuration(delayInterval)
	if err != nil {
		log.Printf("error while parsing initial delay interval '%s': %v", delayInterval, err)
		return
	}
	time.Sleep(interval)
}
