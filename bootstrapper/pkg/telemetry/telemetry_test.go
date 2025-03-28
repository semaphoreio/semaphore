package telemetry_test

import (
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/google/uuid"
	"github.com/semaphoreio/semaphore/bootstrapper/pkg/telemetry"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestSendTelemetryInstallationData(t *testing.T) {
	instId := uuid.New().String()

	// Create a mock HTTP server
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {

		require.Equal(t, "POST", r.Method)
		require.Equal(t, "application/json", r.Header.Get("Content-Type"))

		body, err := io.ReadAll(r.Body)
		require.NoError(t, err)
		defer r.Body.Close()

		var requestPayload telemetry.RequestPayload
		err = json.Unmarshal(body, &requestPayload)
		require.NoError(t, err)

		assert.Equal(t, instId, requestPayload.InstallationId)
		assert.Equal(t, "v1.23.0+k3s1", requestPayload.KubeVersion)
		assert.Equal(t, "1.0.0", requestPayload.Version)
		assert.Equal(t, 0, requestPayload.ProjectsCount)
		assert.Equal(t, 1, requestPayload.OrgMembersCount)
		assert.Equal(t, "installed", requestPayload.State)

		// Respond with HTTP 200 OK
		w.WriteHeader(http.StatusOK)
	}))
	defer server.Close()

	// Create telemetry client and test data
	client := telemetry.NewTelemetryClient("1.0.0")
	installationDefaults := map[string]string{
		"telemetry_endpoint": server.URL,
		"installation_id":    instId,
		"kube_version":       "v1.23.0+k3s1",
	}

	// Call function to be tested
	client.SendTelemetryInstallationData(installationDefaults)
}
