package middleware

import (
	"fmt"
	"net/http"
	"os"
	"strings"

	"github.com/golang/glog"
	"github.com/google/uuid"
	"github.com/grpc-ecosystem/grpc-gateway/v2/runtime"
	"google.golang.org/protobuf/types/known/timestamppb"

	"github.com/semaphoreio/semaphore/public-api-gateway/api/clients"
	auditProto "github.com/semaphoreio/semaphore/public-api-gateway/protos/audit"
)

var auditPaths = []string{
	"/api/v1alpha/jobs",
}

var auditClient *clients.AuditClient

// AuditMiddleware creates a new audit middleware function that implements runtime.Middleware
func AuditMiddleware() runtime.Middleware {
	// Return the middleware function that wraps the handler
	return func(next runtime.HandlerFunc) runtime.HandlerFunc {
		return auditMiddleware(next)
	}
}

func auditMiddleware(next runtime.HandlerFunc) runtime.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request, pathParams map[string]string) {
		// Check if this path should be audited
		if !shouldAudit(r) {
			next(w, r, pathParams)
			return
		}
		var err error
		if auditClient == nil {
			auditClient, err = initAuditClient()
			// If audit client is nil, respond with error
			if err != nil {
				glog.Warningf("Failed to initialize audit client. API calls will not be audited.")
				w.WriteHeader(http.StatusServiceUnavailable)
				w.Write([]byte("Failed to audit operation"))
				return
			}
		}

		// Create a response recorder to capture the response
		rw := NewResponseRecorder(w)

		// Serve the request with the response recorder
		next(rw, r, pathParams)

		// Log the status code
		statusCode := rw.Status

		// Only audit successful responses
		if statusCode < 200 || statusCode >= 300 {
			return
		}

		// Extract audit information
		auditEvent, err := createAuditEvent(r, pathParams)
		if err != nil {
			glog.Errorf("Failed to create audit event: %v", err)
			return
		}

		// Audit the call
		err = auditClient.SendAuditEvent(r.Context(), &auditEvent)
		if err != nil {
			glog.Errorf("Failed to send audit event: %v", err)
		}
	}
}

// shouldAudit determines if this handler should process the request
func shouldAudit(r *http.Request) bool {
	for _, path := range auditPaths {
		if strings.Contains(r.URL.Path, path) {
			return true
		}
	}
	return false
}

// createAuditEvent creates an AuditEvent from a request
func createAuditEvent(r *http.Request, pathParams map[string]string) (auditProto.Event, error) {
	if strings.HasPrefix(r.URL.Path, "/api/v1alpha/jobs") {
		return createJobAuditEvent(r, pathParams)
	}
	return auditProto.Event{}, fmt.Errorf("path is not auditable: %s", r.URL.Path)
}

func createJobAuditEvent(r *http.Request, pathParams map[string]string) (auditEvent auditProto.Event, err error) {
	// Default values
	auditEvent = createDefaultAuditEvent(r, auditProto.Event_Job, "")

	var operation auditProto.Event_Operation
	var description string
	resourceID := ""

	// Extract job ID from path if present
	pathParts := strings.Split(r.URL.Path, "/")
	if len(pathParts) > 4 && pathParts[3] == "jobs" && pathParts[4] != "" && pathParts[4] != "project_debug" {
		resourceID = pathParts[4]
	}

	switch r.Method {
	case http.MethodPost:
		if strings.Contains(r.URL.Path, "/stop") {
			operation = auditProto.Event_Stopped
			description = "Stopped the job"
		}
	default:
		err = fmt.Errorf("job operation not auditable")
		return
	}

	auditEvent.Operation = operation
	auditEvent.Description = description
	auditEvent.ResourceId = resourceID

	return
}

func createDefaultAuditEvent(r *http.Request, resource auditProto.Event_Resource, resourceName string) auditProto.Event {
	// Extract user information from request
	userID := r.Header.Get("x-semaphore-user-id")
	orgID := r.Header.Get("x-semaphore-org-id")
	ipAddress := detectRemoteAddress(r)
	medium := detectEventMedium(r)
	return auditProto.Event{
		UserId:       userID,
		OrgId:        orgID,
		Resource:     resource,
		ResourceName: resourceName,
		OperationId:  uuid.NewString(),
		Description:  "",
		Timestamp:    timestamppb.Now(),
		Medium:       medium,
		IpAddress:    ipAddress,
	}
}

// initAuditClient initializes the audit client for API call auditing
func initAuditClient() (*clients.AuditClient, error) {
	amqpURL := os.Getenv("AMQP_URL")
	if amqpURL == "" {
		return nil, fmt.Errorf("AMQP_URL environment variable not set")
	}

	auditClient, err := clients.NewAuditClient(clients.AuditClientConfig{
		AMQPURL: amqpURL,
	})

	if err != nil {
		return nil, fmt.Errorf("failed to create audit client: %w", err)
	}

	return auditClient, nil
}

// detectRemoteAddress extracts the client IP address from an HTTP request,
// taking into account various proxy headers
func detectRemoteAddress(r *http.Request) string {
	// Check for X-Forwarded-For header (common for proxies)
	if xff := r.Header.Get("X-Forwarded-For"); xff != "" {
		// X-Forwarded-For can contain multiple IPs, the second from the end is the original client
		ips := strings.Split(xff, ",")
		ip := strings.TrimSpace(ips[len(ips)-2])
		if ip != "" {
			return ip
		}
	}

	// Check for X-Real-IP header (used by some proxies)
	if xrip := r.Header.Get("X-Real-IP"); xrip != "" {
		return xrip
	}

	// Fall back to RemoteAddr if no proxy headers are found
	return r.RemoteAddr
}

func detectEventMedium(r *http.Request) auditProto.Event_Medium {
	if strings.Contains(r.UserAgent(), "SemaphoreCLI") {
		return auditProto.Event_CLI
	}
	return auditProto.Event_API
}
