package middleware

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/google/uuid"
	"github.com/grpc-ecosystem/grpc-gateway/v2/runtime"

	auditProto "github.com/semaphoreio/semaphore/public-api-gateway/protos/audit"
)

type testAuditClient interface {
	SendAuditEvent(ctx context.Context, event *auditProto.Event) error
	Close() error
}

// MockAuditClient is a mock implementation of the audit client
type MockAuditClient struct {
	sentEvents []*auditProto.Event
	shouldFail bool
}

func NewMockAuditClient() *MockAuditClient {
	return &MockAuditClient{
		sentEvents: make([]*auditProto.Event, 0),
	}
}

func (m *MockAuditClient) SendAuditEvent(ctx context.Context, event *auditProto.Event) error {
	if m.shouldFail {
		return errors.New("mock audit client error")
	}
	m.sentEvents = append(m.sentEvents, event)
	return nil
}

func (m *MockAuditClient) Close() error {
	return nil
}

// testAuditMiddleware is a test version of auditMiddleware that accepts our mock client
func testAuditMiddleware(next runtime.HandlerFunc, client testAuditClient) runtime.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request, pathParams map[string]string) {
		if client == nil {
			next(w, r, pathParams)
			return
		}
		if !shouldAudit(r) {
			next(w, r, pathParams)
			return
		}

		rw := NewResponseRecorder(w)

		next(rw, r, pathParams)

		statusCode := rw.Status
		if statusCode < 200 || statusCode >= 300 {
			return
		}

		auditEvent, err := createAuditEvent(r, pathParams)
		if err != nil {
			return
		}

		client.SendAuditEvent(r.Context(), &auditEvent)
	}
}

// TestAuditMiddleware tests the audit middleware functionality
func TestAuditMiddleware(t *testing.T) {
	testHandler := func(w http.ResponseWriter, r *http.Request, pathParams map[string]string) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"id": "test-job-id"}`))
	}

	t.Run("Should audit job stop requests", func(t *testing.T) {
		mockClient := NewMockAuditClient()

		middleware := func(next runtime.HandlerFunc) runtime.HandlerFunc {
			return testAuditMiddleware(next, mockClient)
		}

		handlerWithMiddleware := middleware(testHandler)
		jobID := uuid.NewString()
		req := httptest.NewRequest("POST", "/api/v1alpha/jobs/"+jobID+"/stop", nil)
		req.Header.Set("x-semaphore-user-id", "user-123")
		req.Header.Set("x-semaphore-org-id", "org-123")

		rr := httptest.NewRecorder()

		pathParams := map[string]string{
			"job_id": jobID,
		}
		handlerWithMiddleware(rr, req, pathParams)

		if rr.Code != http.StatusOK {
			t.Errorf("Expected status code %d, got %d", http.StatusOK, rr.Code)
		}

		if len(mockClient.sentEvents) != 1 {
			t.Errorf("Expected 1 audit event to be sent, got %d", len(mockClient.sentEvents))
			return
		}

		event := mockClient.sentEvents[0]
		if event.Resource != auditProto.Event_Job {
			t.Errorf("Expected resource to be Job, got %v", event.Resource)
		}
		if event.Operation != auditProto.Event_Stopped {
			t.Errorf("Expected operation to be Stopped, got %v", event.Operation)
		}
		if event.ResourceId != jobID {
			t.Errorf("Expected resource ID to be %s, got %s", jobID, event.ResourceId)
		}
	})

	t.Run("Should not audit non-job requests", func(t *testing.T) {
		mockClient := NewMockAuditClient()

		middleware := func(next runtime.HandlerFunc) runtime.HandlerFunc {
			return testAuditMiddleware(next, mockClient)
		}

		handlerWithMiddleware := middleware(testHandler)

		req := httptest.NewRequest("GET", "/api/v1alpha/dashboards", nil)

		rr := httptest.NewRecorder()

		handlerWithMiddleware(rr, req, map[string]string{})

		if rr.Code != http.StatusOK {
			t.Errorf("Expected status code %d, got %d", http.StatusOK, rr.Code)
		}

		if len(mockClient.sentEvents) != 0 {
			t.Errorf("Expected no audit events to be sent, got %d", len(mockClient.sentEvents))
		}
	})

	t.Run("Should not audit failed requests", func(t *testing.T) {
		mockClient := NewMockAuditClient()

		errorHandler := func(w http.ResponseWriter, r *http.Request, pathParams map[string]string) {
			w.WriteHeader(http.StatusBadRequest)
		}

		middleware := func(next runtime.HandlerFunc) runtime.HandlerFunc {
			return testAuditMiddleware(next, mockClient)
		}

		handlerWithError := middleware(errorHandler)

		jobID := uuid.NewString()
		req := httptest.NewRequest("POST", "/api/v1alpha/jobs/"+jobID+"/stop", nil)

		rr := httptest.NewRecorder()

		pathParams := map[string]string{
			"job_id": jobID,
		}
		handlerWithError(rr, req, pathParams)

		if rr.Code != http.StatusBadRequest {
			t.Errorf("Expected status code %d, got %d", http.StatusBadRequest, rr.Code)
		}

		if len(mockClient.sentEvents) != 0 {
			t.Errorf("Expected no audit events to be sent, got %d", len(mockClient.sentEvents))
		}
	})

	t.Run("Should handle audit client errors gracefully", func(t *testing.T) {
		mockClient := NewMockAuditClient()
		mockClient.shouldFail = true

		middleware := func(next runtime.HandlerFunc) runtime.HandlerFunc {
			return testAuditMiddleware(next, mockClient)
		}

		handlerWithMiddleware := middleware(testHandler)

		jobID := uuid.NewString()
		req := httptest.NewRequest("POST", "/api/v1alpha/jobs/"+jobID+"/stop", nil)
		req.Header.Set("x-semaphore-user-id", "user-123")
		req.Header.Set("x-semaphore-org-id", "org-123")

		rr := httptest.NewRecorder()

		pathParams := map[string]string{
			"job_id": jobID,
		}
		handlerWithMiddleware(rr, req, pathParams)

		if rr.Code != http.StatusOK {
			t.Errorf("Expected status code %d, got %d", http.StatusOK, rr.Code)
		}
	})
}

// TestDetectRemoteAddress tests the detectRemoteAddress function
func TestDetectRemoteAddress(t *testing.T) {
	t.Run("Should detect IP from X-Forwarded-For", func(t *testing.T) {
		req := httptest.NewRequest("GET", "/", nil)
		req.Header.Set("X-Forwarded-For", "10.0.0.1, 192.168.1.1")

		ip := detectRemoteAddress(req)
		if ip != "10.0.0.1" {
			t.Errorf("Expected IP 10.0.0.1, got %s", ip)
		}
	})

	t.Run("Should detect IP from X-Real-IP", func(t *testing.T) {
		req := httptest.NewRequest("GET", "/", nil)
		req.Header.Set("X-Real-IP", "192.168.1.1")

		ip := detectRemoteAddress(req)
		if ip != "192.168.1.1" {
			t.Errorf("Expected IP 192.168.1.1, got %s", ip)
		}
	})

	t.Run("Should fall back to RemoteAddr", func(t *testing.T) {
		req := httptest.NewRequest("GET", "/", nil)
		req.RemoteAddr = "127.0.0.1:1234"

		ip := detectRemoteAddress(req)
		if ip != "127.0.0.1:1234" {
			t.Errorf("Expected IP 127.0.0.1:1234, got %s", ip)
		}
	})
}

// TestDetectEventMedium tests the detectEventMedium function
func TestDetectEventMedium(t *testing.T) {
	t.Run("Should detect CLI medium", func(t *testing.T) {
		req := httptest.NewRequest("GET", "/", nil)
		req.Header.Set("User-Agent", "SemaphoreCLI/1.0")

		medium := detectEventMedium(req)
		if medium != auditProto.Event_CLI {
			t.Errorf("Expected medium CLI, got %v", medium)
		}
	})

	t.Run("Should default to API medium", func(t *testing.T) {
		req := httptest.NewRequest("GET", "/", nil)
		req.Header.Set("User-Agent", "Mozilla/5.0")

		medium := detectEventMedium(req)
		if medium != auditProto.Event_API {
			t.Errorf("Expected medium API, got %v", medium)
		}
	})
}
