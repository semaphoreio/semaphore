package public

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"

	"github.com/google/uuid"
)

type contextKey string

type RequestTooLargeError struct {
	MaxSize int
}

func (e RequestTooLargeError) Error() string {
	return fmt.Sprintf("Request body is too large - must be up to %d bytes", e.MaxSize)
}

var orgIDKey contextKey = "org-id"

type SourceType string

const (
	SourceTypeGithub    SourceType = "github"
	SourceTypeSemaphore SourceType = "semaphore"
)

func OrganizationMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		sourceType := getSourceTypeFromPath(r.URL.Path)

		organizationID, bodyBytes, err := getOrganizationIDForSource(w, r, sourceType)
		if err != nil {
			// Check if this is a RequestTooLargeError
			if tooLargeErr, ok := err.(RequestTooLargeError); ok {
				http.Error(w, tooLargeErr.Error(), http.StatusRequestEntityTooLarge)
				return
			}

			// Otherwise, return 404 for other errors
			w.WriteHeader(http.StatusNotFound)
			return
		}

		// If we read the body (for sources like Semaphore), restore it for the next handler
		if bodyBytes != nil {
			r.Body = io.NopCloser(bytes.NewBuffer(bodyBytes))
		}

		ctx := context.WithValue(r.Context(), orgIDKey, organizationID)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

// getSourceTypeFromPath determines the webhook source type from the request path
func getSourceTypeFromPath(path string) SourceType {
	if strings.Contains(path, "/sources/") {
		if strings.HasSuffix(path, "/github") {
			return SourceTypeGithub
		} else if strings.HasSuffix(path, "/semaphore") {
			return SourceTypeSemaphore
		}
	}
	return ""
}

// getOrganizationIDForSource extracts organization ID based on the source type
func getOrganizationIDForSource(w http.ResponseWriter, r *http.Request, sourceType SourceType) (uuid.UUID, []byte, error) {
	switch sourceType {
	case SourceTypeSemaphore:
		return getOrganizationIDFromSemaphorePayload(w, r)
	case SourceTypeGithub:
		return getOrganizationIdFromHeader(r)
	default:
		return getOrganizationIdFromHeader(r)
	}
}

// getOrganizationIDFromSemaphorePayload extracts organization ID from Semaphore webhook payload
func getOrganizationIDFromSemaphorePayload(w http.ResponseWriter, r *http.Request) (uuid.UUID, []byte, error) {
	r.Body = http.MaxBytesReader(w, r.Body, MaxEventSize)
	defer r.Body.Close()

	bodyBytes, err := io.ReadAll(r.Body)
	if err != nil {
		if _, ok := err.(*http.MaxBytesError); ok {
			return uuid.Nil, nil, RequestTooLargeError{MaxSize: MaxEventSize}
		}
		return uuid.Nil, nil, fmt.Errorf("error reading request body: %w", err)
	}

	var semaphorePayload struct {
		Organization struct {
			ID string `json:"id"`
		} `json:"organization"`
	}

	if err := json.Unmarshal(bodyBytes, &semaphorePayload); err != nil {
		return uuid.Nil, bodyBytes, fmt.Errorf("invalid JSON payload: %w", err)
	}

	if semaphorePayload.Organization.ID == "" {
		return uuid.Nil, bodyBytes, fmt.Errorf("missing organization ID in payload")
	}

	organizationID, err := uuid.Parse(semaphorePayload.Organization.ID)
	if err != nil {
		return uuid.Nil, bodyBytes, fmt.Errorf("invalid organization ID format: %w", err)
	}

	return organizationID, bodyBytes, nil
}

func getOrganizationIdFromHeader(r *http.Request) (uuid.UUID, []byte, error) {
	orgID := r.Header.Get("x-semaphore-org-id")
	if orgID == "" {
		return uuid.Nil, nil, fmt.Errorf("missing organization ID header")
	}

	organizationID, err := uuid.Parse(orgID)
	if err != nil {
		return uuid.Nil, nil, err
	}

	return organizationID, nil, nil
}
