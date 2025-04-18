package public

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/google/uuid"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/database"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/encryptor"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/models"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func Test__HealthCheckEndpoint(t *testing.T) {
	server, err := NewServer(&encryptor.NoOpEncryptor{}, "")
	require.NoError(t, err)

	response := execRequest(server, requestParams{
		method: "GET",
		path:   "/",
	})

	require.Equal(t, 200, response.Code)
}

func Test__ReceiveGitHubEvent(t *testing.T) {
	require.NoError(t, database.TruncateTables())

	server, err := NewServer(&encryptor.NoOpEncryptor{}, "")
	require.NoError(t, err)

	orgID := uuid.New()
	userID := uuid.New()
	canvas, err := models.CreateCanvas(orgID, userID, "test")
	require.NoError(t, err)

	eventSource, err := canvas.CreateEventSource("github-repo-1", []byte("my-key"))
	require.NoError(t, err)

	validEvent := `{"action": "created"}`
	validSignature := "sha256=ee9f99fa8d06b44ffc69ee1c2a7e32e848e8b40536bb5e8405dabb3bbbcaf619"
	validURL := "/sources/" + eventSource.ID.String() + "/github"

	t.Run("missing organization header -> 404", func(t *testing.T) {
		response := execRequest(server, requestParams{
			method: "POST",
			path:   validURL,
			orgID:  "",
		})

		require.Equal(t, 404, response.Code)
	})

	t.Run("invalid organization header -> 404", func(t *testing.T) {
		response := execRequest(server, requestParams{
			method:      "POST",
			path:        validURL,
			orgID:       "not-a-uuid",
			body:        validEvent,
			signature:   validSignature,
			contentType: "application/json",
		})

		require.Equal(t, 404, response.Code)
	})

	t.Run("event for invalid source -> 404", func(t *testing.T) {
		invalidURL := "/sources/invalidsource/github"
		response := execRequest(server, requestParams{
			method:      "POST",
			path:        invalidURL,
			orgID:       orgID.String(),
			body:        validEvent,
			signature:   validSignature,
			contentType: "application/json",
		})

		assert.Equal(t, 404, response.Code)
		assert.Equal(t, "source ID not found\n", response.Body.String())
	})

	t.Run("missing Content-Type header -> 400", func(t *testing.T) {
		response := execRequest(server, requestParams{
			method:      "POST",
			path:        validURL,
			orgID:       orgID.String(),
			body:        validEvent,
			signature:   validSignature,
			contentType: "",
		})

		assert.Equal(t, 404, response.Code)
	})

	t.Run("unsupported Content-Type header -> 400", func(t *testing.T) {
		response := execRequest(server, requestParams{
			method:      "POST",
			path:        validURL,
			orgID:       orgID.String(),
			body:        validEvent,
			signature:   validSignature,
			contentType: "application/x-www-form-urlencoded",
		})

		assert.Equal(t, 404, response.Code)
	})

	t.Run("event for source that does not exist -> 404", func(t *testing.T) {
		invalidURL := "/sources/" + uuid.New().String() + "/github"
		response := execRequest(server, requestParams{
			method:      "POST",
			path:        invalidURL,
			orgID:       orgID.String(),
			body:        validEvent,
			signature:   validSignature,
			contentType: "application/json",
		})

		assert.Equal(t, 404, response.Code)
		assert.Equal(t, "source ID not found\n", response.Body.String())
	})

	t.Run("event with missing signature header -> 400", func(t *testing.T) {
		response := execRequest(server, requestParams{
			method:      "POST",
			path:        validURL,
			orgID:       orgID.String(),
			body:        validEvent,
			signature:   "",
			contentType: "application/json",
		})

		assert.Equal(t, 400, response.Code)
		assert.Equal(t, "Missing X-Hub-Signature-256 header\n", response.Body.String())
	})

	t.Run("invalid signature -> 403", func(t *testing.T) {
		response := execRequest(server, requestParams{
			method:      "POST",
			path:        validURL,
			orgID:       orgID.String(),
			body:        validEvent,
			signature:   "sha256=823a7b73b066321f4f644e70e1d32c15dc8f4677968149c1f35eb07639013271",
			contentType: "application/json",
		})

		assert.Equal(t, 403, response.Code)
		assert.Equal(t, "Invalid signature\n", response.Body.String())
	})

	t.Run("properly signed event is received -> 200", func(t *testing.T) {
		response := execRequest(server, requestParams{
			method:      "POST",
			path:        validURL,
			orgID:       orgID.String(),
			body:        validEvent,
			signature:   validSignature,
			contentType: "application/json",
		})

		assert.Equal(t, 200, response.Code)

		// event is stored in database
		events, err := models.ListEventsBySourceID(eventSource.ID)
		require.NoError(t, err)
		require.Len(t, events, 1)
		assert.Equal(t, eventSource.ID, events[0].SourceID)
		assert.Equal(t, models.EventStatePending, events[0].State)
		assert.Equal(t, []byte(`{"action": "created"}`), []byte(events[0].Raw))
		assert.NotNil(t, events[0].ReceivedAt)
	})
}

type requestParams struct {
	method      string
	path        string
	orgID       string
	body        string
	signature   string
	contentType string
}

func execRequest(server *Server, params requestParams) *httptest.ResponseRecorder {
	req, _ := http.NewRequest(params.method, params.path, strings.NewReader(params.body))

	if params.contentType != "" {
		req.Header.Add("Content-Type", params.contentType)
	}

	if params.orgID != "" {
		req.Header.Add("x-semaphore-org-id", params.orgID)
	}

	if params.signature != "" {
		req.Header.Add("X-Hub-Signature-256", params.signature)
	}

	res := httptest.NewRecorder()
	server.Router.ServeHTTP(res, req)
	return res
}
