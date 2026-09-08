// Package bench pairs a watchman benchmark with a log line.
//
// Metric names have to stay bounded: repohub shares a statsd sidecar that
// never expires timer series, so a repository URL or an id baked into a metric
// name grows the sidecar's memory until it is OOM killed. Without those ids
// Grafana is aggregate only - it shows that an operation got slower, not which
// repository made it slower. The log line closes that gap: it carries the same
// measurement, plus the repository or project the call was made for, so a spike
// in a graph can be traced back to concrete repositories in the logs.
package bench

import (
	"log"
	"os"
	"strconv"
	"time"

	"github.com/renderedtext/go-watchman"
)

// Only measurements at least this slow are logged, so the fast common path
// stays quiet. Override with BENCHMARK_LOG_THRESHOLD_MS while chasing a spike;
// 0 logs every measurement.
const defaultLogThreshold = 1 * time.Second

const logThresholdEnvVar = "BENCHMARK_LOG_THRESHOLD_MS"

var logThreshold = readLogThreshold(os.Getenv(logThresholdEnvVar))

// Observe submits the metric to watchman under its bounded name, and logs the
// measurement together with target - the repository URL, repository id or
// project id the call was made for - when it is slow enough to be interesting.
//
// Meant to be deferred, in place of watchman.Benchmark:
//
//	defer bench.Observe(time.Now(), "gitrekt.Search", repo.HttpURL)
func Observe(start time.Time, metric string, target string) {
	elapsed := time.Since(start)

	_ = watchman.Benchmark(start, metric)

	if elapsed < logThreshold {
		return
	}

	log.Printf(
		"(bench) metric=%s duration_ms=%d target=%s",
		metric,
		elapsed.Milliseconds(),
		target,
	)
}

func readLogThreshold(raw string) time.Duration {
	if raw == "" {
		return defaultLogThreshold
	}

	ms, err := strconv.Atoi(raw)
	if err != nil || ms < 0 {
		log.Printf(
			"(err) Ignoring %s=%q, using %v",
			logThresholdEnvVar,
			raw,
			defaultLogThreshold,
		)

		return defaultLogThreshold
	}

	return time.Duration(ms) * time.Millisecond
}
