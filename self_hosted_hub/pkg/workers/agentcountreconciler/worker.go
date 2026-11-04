package agentcountreconciler

import (
	"context"
	"time"

	watchman "github.com/renderedtext/go-watchman"
	models "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/models"
	log "github.com/sirupsen/logrus"
)

const WorkerName = "self-hosted-agent-count-reconciler"
const interval = 5 * time.Minute

// Start periodically compares the agent counts used for the registration quota
// with the agents table, and fixes the ones that drifted.
func Start() {
	for {
		time.Sleep(interval)
		Tick()
	}
}

// Tick runs without an advisory lock on purpose: the agent-cleaner deployment
// may run with a single database connection, and holding it for a lock
// would leave none for the reconciliation queries. Running two reconciliations
// at the same time is harmless, since each fix happens under the counter row lock.
func Tick() {
	ctx, cancel := context.WithTimeout(context.Background(), time.Minute)
	defer cancel()

	fixed, err := models.ReconcileAgentCounts(ctx)
	if err != nil {
		log.Errorf("[%s] Error reconciling agent counts: %v", WorkerName, err)
		return
	}

	for _, drift := range fixed {
		log.Warnf("[%s] Fixed agent count for organization %s: stored %d, counted %d", WorkerName, drift.OrganizationID, drift.Stored, drift.Counted)
	}

	_ = watchman.Submit("agent_counts.reconciled", len(fixed))
}
