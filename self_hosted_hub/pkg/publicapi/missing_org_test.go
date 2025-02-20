package publicapi

import (
	"net/http"
	"testing"

	"github.com/semaphoreio/semaphore/self_hosted_hub/pkg/database"
	grpcmock "github.com/semaphoreio/semaphore/self_hosted_hub/test/grpcmock"
	require "github.com/stretchr/testify/require"
)

func Test__MissingOrganization(t *testing.T) {
	type testCase struct {
		path   string
		method string
		token  string
	}

	database.TruncateTables()
	grpcmock.Start()

	// we create valid tokens here, but the organization
	// we will be using in the requests is not the same one.
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
			res, err := runHTTPWithOrg(testCase.method, testCase.path, testCase.token, "", port)
			require.NoError(t, err)
			require.Equal(t, http.StatusNotFound, res.StatusCode)
		})
	}
}
