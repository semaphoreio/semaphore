// Package watchman holds a helper function for configuring watchman's client.
package watchman

import (
	"github.com/renderedtext/go-watchman"
	"log"
	"time"
)

func Configure(metricNamespace string) {
	// Give some time for the statsd sidecar to start up
	time.Sleep(3000 * time.Millisecond)

	err := watchman.Configure("0.0.0.0", "8125", metricNamespace)

	if err != nil {
		log.Printf("(err) Failed to configure watchman")
	}
}
