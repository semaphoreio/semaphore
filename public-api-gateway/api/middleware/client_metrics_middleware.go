package middleware

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"regexp"
	"time"

	"github.com/grpc-ecosystem/grpc-gateway/v2/runtime"
)

// clientRequestEvent is the structured log line emitted once per request.
// Downstream log ingestion turns these into metrics.
type clientRequestEvent struct {
	Severity      string `json:"severity"`
	Message       string `json:"message"`
	ClientSource  string `json:"client_source"`
	ClientCommand string `json:"client_command"`
	ClientVersion string `json:"client_version"`
	ClientOrg     string `json:"client_org"`
	Status        int    `json:"status"`
	DurationMs    int64  `json:"duration_ms"`
}

var (
	knownSources  = map[string]bool{"semai-cli": true, "semai-mcp": true}
	commandRegexp = regexp.MustCompile(`^[a-z0-9_-]{1,50}$`)
	versionRegexp = regexp.MustCompile(`^[A-Za-z0-9._+\-]{1,30}$`)
)

// ClientMetricsMiddleware emits one structured JSON log line per request to
// stdout once the response status is known.
func ClientMetricsMiddleware() runtime.Middleware {
	return func(next runtime.HandlerFunc) runtime.HandlerFunc {
		return func(w http.ResponseWriter, r *http.Request, pathParams map[string]string) {
			start := time.Now()
			rec := NewResponseRecorder(w)

			next(rec, r, pathParams)

			event := clientRequestEvent{
				Severity:      "INFO",
				Message:       "client_request",
				ClientSource:  clientSource(r),
				ClientCommand: sanitize(r.Header.Get("x-client-command"), commandRegexp),
				ClientVersion: sanitize(r.Header.Get("x-client-version"), versionRegexp),
				ClientOrg:     clientOrg(r),
				Status:        rec.Status,
				DurationMs:    time.Since(start).Milliseconds(),
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

// clientOrg reads the auth-set org headers (trusted, never client-supplied).
// Username is preferred for readability; org id is the fallback. Returns "na"
// when unauthenticated.
func clientOrg(r *http.Request) string {
	if name := r.Header.Get("x-semaphore-org-username"); name != "" {
		return name
	}
	if id := r.Header.Get("x-semaphore-org-id"); id != "" {
		return id
	}
	return "na"
}

func sanitize(value string, re *regexp.Regexp) string {
	if value != "" && re.MatchString(value) {
		return value
	}
	return "na"
}
