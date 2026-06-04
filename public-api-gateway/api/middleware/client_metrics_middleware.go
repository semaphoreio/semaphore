package middleware

import (
	"net/http"
	"regexp"
	"time"

	"github.com/grpc-ecosystem/grpc-gateway/v2/runtime"
	watchman "github.com/renderedtext/go-watchman"
)

// Client-attribution metrics for the gateway, implementing the same contract as
// the Elixir plugs: per-request metrics tagged by the client that
// issued the request, read from the x-client-* headers sem-ai attaches.
// Header-less callers tag source=api, so the metric covers all traffic.
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

var (
	knownSources   = map[string]bool{"semai-cli": true, "semai-mcp": true}
	commandRegex   = regexp.MustCompile(`^[a-z0-9_-]{1,50}$`)
	versionRegex   = regexp.MustCompile(`^[A-Za-z0-9._+-]{1,30}$`)
	graphiteUnsafe = regexp.MustCompile(`[.+]`)
)

// ClientMetricsMiddleware records a per-client request metric (timing + status
// counter) plus the generic api.client_usage / api.org_usage counters for every
// gateway request, including 4xx/5xx.
func ClientMetricsMiddleware() runtime.Middleware {
	return func(next runtime.HandlerFunc) runtime.HandlerFunc {
		return func(w http.ResponseWriter, r *http.Request, pathParams map[string]string) {
			start := time.Now()
			rec := NewResponseRecorder(w)

			next(rec, r, pathParams)

			src := clientSource(r)
			tags := []string{src, clientCommand(r), clientVersion(r)}

			_ = watchman.BenchmarkWithTags(start, clientRequestMetric, tags)
			_ = watchman.IncrementWithTags(clientRequestMetric+"."+statusLabel(rec.Status), tags)
			_ = watchman.IncrementWithTags(usageMetric, []string{src})

			if org := orgTag(r); org != "" {
				_ = watchman.IncrementWithTags(orgMetric, []string{org, src})
			}
		}
	}
}

func clientSource(r *http.Request) string {
	if s := r.Header.Get("x-client-source"); knownSources[s] {
		return s
	}
	return "api"
}

func clientCommand(r *http.Request) string {
	return sanitizeTag(r.Header.Get("x-client-command"), commandRegex)
}

func clientVersion(r *http.Request) string {
	return sanitizeTag(r.Header.Get("x-client-version"), versionRegex)
}

func sanitizeTag(v string, re *regexp.Regexp) string {
	if v != "" && re.MatchString(v) {
		return graphiteSafe(v)
	}
	return naTag
}

// orgTag uses the auth-set headers (trusted, never client-supplied);
// username preferred for readability, org id as fallback. "" when unauthenticated.
func orgTag(r *http.Request) string {
	if name := r.Header.Get("x-semaphore-org-username"); name != "" {
		return graphiteSafe(name)
	}
	if id := r.Header.Get("x-semaphore-org-id"); id != "" {
		return graphiteSafe(id)
	}
	return ""
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

// graphiteSafe replaces the carbon path separator "." (and "+") with "_" so a
// tag value can't split into extra path segments and corrupt the measurement.
func graphiteSafe(v string) string {
	return graphiteUnsafe.ReplaceAllString(v, "_")
}
