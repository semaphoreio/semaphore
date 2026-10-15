package publicapi

import (
	"fmt"
	"math/rand"
	"net/http"
	"testing"

	agentsync "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/agentsync"
	"github.com/semaphoreio/semaphore/self_hosted_hub/pkg/database"
	ratelimit "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/ratelimit"
	grpcmock "github.com/semaphoreio/semaphore/self_hosted_hub/test/grpcmock"
	require "github.com/stretchr/testify/require"
)

// withRateLimiter swaps in a limiter for the shared test server for the
// duration of a subtest, restoring the default (disabled) limiter afterwards.
func withRateLimiter(t *testing.T, l *ratelimit.Limiter) {
	original := testServer.rateLimiter
	testServer.rateLimiter = l
	t.Cleanup(func() { testServer.rateLimiter = original })
}

func Test__RegisterRateLimit(t *testing.T) {
	database.TruncateTables()
	grpcmock.Start()

	t.Run("first register allowed, burst-exhausted register blocked with 429", func(t *testing.T) {
		// burst of 1, effectively no refill within the test.
		withRateLimiter(t, ratelimit.New(true, 0.0001, 1))

		_, token, _ := newAgentType(fmt.Sprintf("s1-rl-%d", rand.Int()))

		res := run("POST", "/register", token, registerRequest(fmt.Sprintf("a-%d", rand.Int())))
		require.Equal(t, http.StatusCreated, res.Code)

		res = run("POST", "/register", token, registerRequest(fmt.Sprintf("b-%d", rand.Int())))
		require.Equal(t, http.StatusTooManyRequests, res.Code)
	})

	t.Run("legitimate churn under the limit is not blocked", func(t *testing.T) {
		// generous burst: normal churn must pass.
		withRateLimiter(t, ratelimit.New(true, 100, 50))

		_, token, _ := newAgentType(fmt.Sprintf("s1-rl-ok-%d", rand.Int()))

		for i := 0; i < 5; i++ {
			res := run("POST", "/register", token, registerRequest(fmt.Sprintf("ok-%d-%d", i, rand.Int())))
			require.Equal(t, http.StatusCreated, res.Code)
		}
	})

	t.Run("disabled limiter (default) never blocks register", func(t *testing.T) {
		withRateLimiter(t, ratelimit.New(false, 0.0001, 1))

		_, token, _ := newAgentType(fmt.Sprintf("s1-rl-off-%d", rand.Int()))

		res := run("POST", "/register", token, registerRequest(fmt.Sprintf("x-%d", rand.Int())))
		require.Equal(t, http.StatusCreated, res.Code)
		res = run("POST", "/register", token, registerRequest(fmt.Sprintf("y-%d", rand.Int())))
		require.Equal(t, http.StatusCreated, res.Code)
	})
}

func Test__DisconnectRateLimit(t *testing.T) {
	database.TruncateTables()
	grpcmock.Start()

	t.Run("first disconnect allowed, burst-exhausted disconnect blocked with 429", func(t *testing.T) {
		agentType, _, err := newAgentType(fmt.Sprintf("s1-rl-dc-%d", rand.Int()))
		require.NoError(t, err)

		// Register two agents through the model, so the limiter is untouched
		// by their creation and both agents are valid targets to disconnect.
		_, tokenA, err := newAgent(agentType)
		require.NoError(t, err)
		_, tokenB, err := newAgent(agentType)
		require.NoError(t, err)

		withRateLimiter(t, ratelimit.New(true, 0.0001, 1))

		res := run("POST", "/disconnect", tokenA, nil)
		require.Equal(t, http.StatusOK, res.Code)

		res = run("POST", "/disconnect", tokenB, nil)
		require.Equal(t, http.StatusTooManyRequests, res.Code)
	})

	t.Run("legitimate disconnect churn under the limit is not blocked", func(t *testing.T) {
		agentType, _, err := newAgentType(fmt.Sprintf("s1-rl-dc-ok-%d", rand.Int()))
		require.NoError(t, err)

		withRateLimiter(t, ratelimit.New(true, 100, 50))

		for i := 0; i < 3; i++ {
			_, token, err := newAgent(agentType)
			require.NoError(t, err)

			// keep the agent state machine happy before disconnect
			sync(t, syncAssertion{
				state:  agentsync.AgentStateWaitingForJobs,
				token:  token,
				action: agentsync.AgentActionContinue,
			})

			res := run("POST", "/disconnect", token, nil)
			require.Equal(t, http.StatusOK, res.Code)
		}
	})
}
