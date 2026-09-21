package bucketcleaner

import (
	"fmt"
	"log"
	"os"
	"time"
)

// DefaultPurgeGracePeriod is how long a deleted project's artifacts are kept before
// the storage is emptied.
//
// The wait is what makes the delete reversible: restoring the project inside the
// window cancels the purge, so the artifacts come back with it. Emptying the storage
// as soon as the delete arrives leaves nothing to restore.
const DefaultPurgeGracePeriod = 24 * time.Hour

// PurgeGracePeriodEnvVar holds a Go duration, for example "24h", "90m" or "0".
// Zero means purge as soon as the delete is seen, which is the behaviour this grace
// period replaced.
const PurgeGracePeriodEnvVar = "ARTIFACT_PURGE_GRACE_PERIOD"

// PurgeGracePeriod is read by the scheduler, to decide what is due, and by the
// cleaner, to decide what to delete. Both run from the same binary, so main sets it
// once at startup.
var PurgeGracePeriod = DefaultPurgeGracePeriod

// ConfigurePurgeGracePeriod reads the grace period from the environment, falling
// back to the default when it is unset or unparseable. A bad value must not stop the
// service from starting, and the fallback errs towards keeping artifacts.
func ConfigurePurgeGracePeriod() {
	raw, set := os.LookupEnv(PurgeGracePeriodEnvVar)
	if !set || raw == "" {
		PurgeGracePeriod = DefaultPurgeGracePeriod
		log.Printf("BucketCleaner: purge grace period %s (default)", PurgeGracePeriod)

		return
	}

	grace, err := time.ParseDuration(raw)
	if err != nil || grace < 0 {
		PurgeGracePeriod = DefaultPurgeGracePeriod
		log.Printf("BucketCleaner: could not read %s=%q, using %s", PurgeGracePeriodEnvVar, raw, PurgeGracePeriod)

		return
	}

	PurgeGracePeriod = grace
	log.Printf("BucketCleaner: purge grace period %s", PurgeGracePeriod)
}

// postgresInterval renders a duration for CAST(? AS interval). Seconds keep it exact
// and free of locale-dependent parsing.
func postgresInterval(d time.Duration) string {
	return fmt.Sprintf("%d seconds", int64(d.Seconds()))
}
