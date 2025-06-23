package middleware

import (
	"encoding/json"
	"fmt"
	"net/http"
	"regexp"
	"strings"

	"github.com/golang/glog"
	"github.com/google/uuid"
	"github.com/grpc-ecosystem/grpc-gateway/v2/runtime"
	"google.golang.org/protobuf/types/known/timestamppb"

	"github.com/semaphoreio/semaphore/public-api-gateway/api/clients"
	auditProto "github.com/semaphoreio/semaphore/public-api-gateway/protos/audit"
)

type auditor func(r *http.Request, pathParams map[string]string) (auditProto.Event, error)

var (
	// errNotAuditable is returned when a request is not auditable
	errNotAuditable = fmt.Errorf("path is not auditable")

	// auditPaths maps regular expressions to auditors
	// regular expressions are used to match request URL path
	auditPaths = map[*regexp.Regexp]auditor{
		regexp.MustCompile("/api/v1alpha/jobs/[0-9a-fA-F-]+/stop"): createStopJobAuditEvent,
	}
)

// AuditMiddleware creates a new audit middleware function that implements runtime.Middleware.
// This middleware will audit some requests to the API.
func AuditMiddleware(auditClient *clients.AuditClient) runtime.Middleware {
	// Return the middleware function that wraps the handler
	return func(next runtime.HandlerFunc) runtime.HandlerFunc {
		return auditMiddleware(next, auditClient)
	}
}

func auditMiddleware(next runtime.HandlerFunc, auditClient *clients.AuditClient) runtime.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request, pathParams map[string]string) {
		// Check if this path should be audited
		if !shouldAudit(r) {
			next(w, r, pathParams)
			return
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
		if err == errNotAuditable {
			return
		}
		if err != nil {
			glog.Errorf("Failed to create audit event: %v", err)
			errResponse := fmt.Errorf("failed to create audit event: %v", err)
			respondWithJSON(w, http.StatusInternalServerError, map[string]interface{}{
				"error": errResponse.Error(),
			})
			return
		}

		err = auditClient.SendAuditEvent(r.Context(), &auditEvent)
		if err != nil {
			glog.Errorf("Failed to send audit event: %v", err)
			errResponse := fmt.Errorf("failed to send audit event: %v", err)
			respondWithJSON(w, http.StatusInternalServerError, map[string]interface{}{
				"error": errResponse.Error(),
			})
			return
		}
	}
}

// shouldAudit determines if this handler should process the request
func shouldAudit(r *http.Request) bool {
	for rePath := range auditPaths {
		if rePath.MatchString(r.URL.Path) {
			return true
		}
	}
	return false
}

// createAuditEvent creates an AuditEvent from a request
func createAuditEvent(r *http.Request, pathParams map[string]string) (auditProto.Event, error) {
	for rePath, auditor := range auditPaths {
		if rePath.MatchString(r.URL.Path) {
			return auditor(r, pathParams)
		}
	}
	return auditProto.Event{}, errNotAuditable
}

func createStopJobAuditEvent(r *http.Request, pathParams map[string]string) (auditEvent auditProto.Event, err error) {
	if r.Method != http.MethodPost {
		return auditProto.Event{}, errNotAuditable
	}
	resourceID, ok := pathParams["job_id"]
	if !ok {
		return auditProto.Event{}, errNotAuditable
	}

	metadataMap := map[string]string{
		"job_id":       resourceID,
		"requester_id": r.Header.Get("x-semaphore-user-id"),
	}

	metadata, err := json.Marshal(metadataMap)
	if err != nil {
		err = fmt.Errorf("error marshaling metadata: %v", err)
		return
	}
	auditEvent = createDefaultAuditEvent(r, auditProto.Event_Job, "")
	auditEvent.Operation = auditProto.Event_Stopped
	auditEvent.Description = "Stopped the job"
	auditEvent.ResourceId = resourceID
	auditEvent.Metadata = string(metadata)

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
		Metadata:     "{}",
	}
}

// detectRemoteAddress extracts the client IP address from an HTTP request,
// taking into account various proxy headers
func detectRemoteAddress(r *http.Request) string {
	// Check for X-Forwarded-For header
	if xff := r.Header.Get("X-Forwarded-For"); xff != "" {
		// X-Forwarded-For can contain multiple IPs, the second from the end is the original client
		ips := strings.Split(xff, ",")
		if len(ips) >= 2 {
			ip := strings.TrimSpace(ips[len(ips)-2])
			if ip != "" {
				return ip
			}
		}
	}

	// Check for X-Real-IP header
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

// respondWithJSON writes a JSON response with the given status code and payload
func respondWithJSON(w http.ResponseWriter, statusCode int, payload interface{}) {
	response, err := json.Marshal(payload)
	if err != nil {
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(statusCode)

	_, err = w.Write(response)
	if err != nil {
		glog.Errorf("Failed to write response: %v", err)
	}
}
