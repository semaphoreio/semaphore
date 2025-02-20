package publicapi

import (
	"fmt"
	"math/rand"
	"net/http"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/require"
)

func Test__Timeout(t *testing.T) {
	type testCase struct {
		path   string
		method string
		token  string
	}

	jobID := uuid.New()
	pullToken := generateJwtToken(jobID.String(), "PULL")
	pushToken := generateJwtToken(jobID.String(), "PUSH")

	for _, testCase := range []testCase{
		{path: "api/v1/logs/" + jobID.String(), method: "POST", token: pushToken},
		{path: "api/v1/logs/" + jobID.String(), method: "GET", token: pullToken},
	} {
		t.Run(fmt.Sprintf("%s_%s", testCase.path, testCase.method), func(t *testing.T) {
			server, port := setupServer(t)
			defer server.Close()
			res, err := runHTTP(testCase.method, testCase.path, testCase.token, port)
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

	server, err := NewServer(redisStorage, gcsStorage, privateKey, noResponseMiddleware)
	require.NoError(t, err)
	server.SetTimeoutHandlerTimeout(time.Second)
	port := 10000 + rand.Intn(1000)
	go server.Serve("0.0.0.0", port)

	// Make sure the server is listening before returning.
	isHealthy := func() bool {
		res, err := runHTTP("GET", "", "", port)
		if err != nil {
			return false
		}

		return res.StatusCode == http.StatusOK
	}

	require.Eventually(t, func() bool { return isHealthy() }, time.Second, 10*time.Millisecond)

	return server, port
}

func runHTTP(method, path, token string, port int) (*http.Response, error) {
	req, err := http.NewRequest(method, fmt.Sprintf("http://0.0.0.0:%d/%s", port, path), nil)
	if err != nil {
		return nil, err
	}

	req.Header.Add("Authorization", "Bearer "+token)
	req.Header.Add("x-forwarded-for", "1.1.1.1")
	req.Header.Add("x-semaphore-org-id", uuid.NewString())
	req.Header.Add("user-agent", "Agent/v1.2.3")

	return http.DefaultClient.Do(req)
}
