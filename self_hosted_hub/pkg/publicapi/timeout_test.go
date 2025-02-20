package publicapi

import (
	"fmt"
	"math/rand"
	"net/http"
	"testing"
	"time"

	"github.com/semaphoreio/semaphore/self_hosted_hub/pkg/database"
	require "github.com/stretchr/testify/require"
)

func Test__Timeout(t *testing.T) {
	type testCase struct {
		path   string
		method string
		token  string
	}

	database.TruncateTables()

	agentType, agentTypeToken, err := newAgentType("s1-test")
	require.NoError(t, err)

	_, agentToken, err := newAgent(agentType)
	require.NoError(t, err)

	for _, testCase := range []testCase{
		{path: "api/v1/self_hosted_agents/register", method: "POST", token: agentTypeToken},
		{path: "api/v1/self_hosted_agents/metrics", method: "GET", token: agentTypeToken},
		{path: "api/v1/self_hosted_agents/occupancy", method: "GET", token: agentTypeToken},
		{path: "api/v1/self_hosted_agents/sync", method: "POST", token: agentToken},
		{path: "api/v1/self_hosted_agents/refresh", method: "POST", token: agentToken},
		{path: "api/v1/self_hosted_agents/jobs/job-1234", method: "GET", token: agentToken},
		{path: "api/v1/self_hosted_agents/disconnect", method: "POST", token: agentToken},
	} {
		t.Run(testCase.path, func(t *testing.T) {
			server, port := setupServer(t)
			defer server.Close()
			res, err := runHTTPWithOrg(testCase.method, testCase.path, testCase.token, testOrgID.String(), port)
			require.NoError(t, err)
			require.Equal(t, http.StatusServiceUnavailable, res.StatusCode)
		})
	}
}

func setupServer(t *testing.T) (*Server, int) {
	noResponseMiddleware := func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			time.Sleep(time.Hour)
		})
	}

	server, err := NewServer(quotaClient, agentCounter, publisher, noResponseMiddleware)
	require.NoError(t, err)
	server.SetTimeoutHandlerTimeout(time.Second)
	port := 10000 + rand.Intn(1000)
	go server.Serve("0.0.0.0", port)

	// Make sure the server is listening before returning.
	isHealthy := func() bool {
		res, err := runHTTPWithOrg("GET", "", "", "", port)
		if err != nil {
			return false
		}

		return res.StatusCode == http.StatusOK
	}

	require.Eventually(t, func() bool { return isHealthy() }, time.Second, 10*time.Millisecond)

	return server, port
}

func runHTTPWithOrg(method, path, token, org string, port int) (*http.Response, error) {
	req, err := http.NewRequest(method, fmt.Sprintf("http://0.0.0.0:%d/%s", port, path), nil)
	if err != nil {
		return nil, err
	}

	req.Header.Add("Authorization", "Token "+token)
	req.Header.Add("x-semaphore-org-id", org)
	req.Header.Add("user-agent", "Agent/v1.2.3")

	return http.DefaultClient.Do(req)
}
