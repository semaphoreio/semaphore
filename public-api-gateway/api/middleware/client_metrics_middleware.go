package middleware

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"regexp"
	"time"

	"github.com/grpc-ecosystem/grpc-gateway/v2/runtime"
	watchman "github.com/renderedtext/go-watchman"
)

// Client-attribution for the gateway, implementing the same contract as the
// Elixir plugs: per-request metrics plus one structured JSON log line, both
// describing which client issued the request (read from the x-client-*
// headers sem-ai attaches). Header-less callers tag source=api, so both
// outputs cover all traffic.
const (
	// Per-service rich metric (app-namespaced; status is in the NAME because the
	// statsd_graphite backend keeps only 3 positional tags).
	clientRequestMetric = "PublicApiGateway.router.client_request"
	// Generic, service-agnostic counters — identical names across every backend
	// so cli-vs-mcp-vs-api (client_usage) and per-org volume (org_usage)
	// aggregate cross-service (the Watchman MetricPrefix gives the service tag).
	usageMetric = "api.client_usage"
	orgMetric   = "api.org_usage"
	naTag       = "na"
)

// clientRequestEvent is the structured log line emitted once per request. It
// carries the full-fidelity values (raw dotted version) that don't belong in
// metric tags.
type clientRequestEvent struct {
	Severity      string `json:"severity"`
	Message       string `json:"message"`
	ClientSource  string `json:"client_source"`
	ClientCommand string `json:"client_command"`
	ClientVersion string `json:"client_version"`
	ClientOrgID   string `json:"client_org_id"`
	Status        int    `json:"status"`
	DurationMs    int64  `json:"duration_ms"`
}

var (
	knownSources   = map[string]bool{"semai-cli": true, "semai-mcp": true}
	commandRegexp  = regexp.MustCompile(`^[a-z0-9_-]{1,50}$`)
	versionRegexp  = regexp.MustCompile(`^[A-Za-z0-9._+\-]{1,30}$`)
	graphiteUnsafe = regexp.MustCompile(`[.+]`)
)

// ClientMetricsMiddleware records a per-client request metric (timing + status
// counter) plus the generic api.client_usage / api.org_usage counters, and
// emits one structured JSON log line to stdout, for every request that reaches
// a registered handler — including handler-produced 4xx/5xx. Routing-level
// failures (unknown path 404, method-not-allowed 405) never enter mux
// middlewares and are not recorded.
func ClientMetricsMiddleware() runtime.Middleware {
	return func(next runtime.HandlerFunc) runtime.HandlerFunc {
		return func(w http.ResponseWriter, r *http.Request, pathParams map[string]string) {
			start := time.Now()
			rec := NewResponseRecorder(w)

			next(rec, r, pathParams)

			durationMs := time.Since(start).Milliseconds()
			src := clientSource(r)
			tags := []string{src, clientCommandTag(r), clientVersionTag(r)}

			// The Elixir plugs submit this timer in milliseconds; go-watchman's
			// BenchmarkWithTags would emit microseconds, so submit ms explicitly
			// to keep the unit consistent across all backends.
			_ = watchman.TimingWithTags(clientRequestMetric, tags, durationMs)
			_ = watchman.IncrementWithTags(clientRequestMetric+"."+statusLabel(rec.Status), tags)
			_ = watchman.IncrementWithTags(usageMetric, []string{src})

			if org := clientOrgID(r); org != naTag {
				_ = watchman.IncrementWithTags(orgMetric, []string{graphiteSafe(org), src})
			}

			event := clientRequestEvent{
				Severity:      "INFO",
				Message:       "client_request",
				ClientSource:  src,
				ClientCommand: sanitize(r.Header.Get("x-client-command"), commandRegexp),
				ClientVersion: sanitize(r.Header.Get("x-client-version"), versionRegexp),
				ClientOrgID:   clientOrgID(r),
				Status:        rec.Status,
				DurationMs:    durationMs,
			}

			b, _ := json.Marshal(event)
			fmt.Fprintln(os.Stdout, string(b))
		}
	}
}

func clientSource(r *http.Request) string {
	if s := r.Header.Get("x-client-source"); knownSources[s] {
		return s
	}
	return "api"
}

func clientCommandTag(r *http.Request) string {
	return graphiteSafe(sanitize(r.Header.Get("x-client-command"), commandRegexp))
}

func clientVersionTag(r *http.Request) string {
	return graphiteSafe(sanitize(r.Header.Get("x-client-version"), versionRegexp))
}

// clientOrgID reads the auth-set org id (trusted, stable, never
// client-supplied). Returns "na" when unauthenticated.
func clientOrgID(r *http.Request) string {
	if id := r.Header.Get("x-semaphore-org-id"); id != "" {
		return id
	}
	return naTag
}

func statusLabel(status int) string {
	switch {
	case status >= 500:
		return "server_error"
	case status >= 400:
		return "client_error"
	case status > 0:
		return "ok"
	default:
		return "unknown"
	}
}

func sanitize(value string, re *regexp.Regexp) string {
	if value != "" && re.MatchString(value) {
		return value
	}
	return naTag
}

// graphiteSafe replaces the carbon path separator "." (and "+") with "_" so a
// tag value can't split into extra path segments and corrupt the measurement.
func graphiteSafe(v string) string {
	return graphiteUnsafe.ReplaceAllString(v, "_")
}
