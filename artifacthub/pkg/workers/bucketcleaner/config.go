package bucketcleaner

import (
	"fmt"
	"log"
	"os"
	"time"
)

// DefaultPurgeGracePeriod is how long a deleted project's artifacts are kept before
// the storage is emptied. Restoring the project inside it brings the artifacts back.
const DefaultPurgeGracePeriod = 24 * time.Hour

// PurgeGracePeriodEnvVar holds a Go duration such as "24h" or "90m". Zero empties the
// storage as soon as the delete is seen.
const PurgeGracePeriodEnvVar = "ARTIFACT_PURGE_GRACE_PERIOD"

// PurgeGracePeriod is read by the scheduler, to pick due storages, and by the cleaner,
// which never empties one before its own value is up. They are separate deployments, so
// set it on both; the cleaner's value is the one that protects a restore.
var PurgeGracePeriod = DefaultPurgeGracePeriod

// PurgeEnabled is whether this process empties storages that a project delete marked. Off
// unless the feature is enabled here, so turning it off stops purges at once.
var PurgeEnabled = false

// ConfigurePurgeGracePeriod reads the grace period from the environment. A value that
// does not parse is logged and replaced by the default rather than stopping the service.
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
