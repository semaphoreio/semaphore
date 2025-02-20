package publicapi

import (
	"encoding/json"
	"fmt"
	"io"
	"io/ioutil"
	"math/rand"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
	amqp091 "github.com/rabbitmq/amqp091-go"
	agentsync "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/agentsync"
	amqp "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/amqp"
	database "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/database"
	"github.com/semaphoreio/semaphore/self_hosted_hub/pkg/feature"
	models "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/models"
	auditProtos "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/protos/audit"
	zebrapb "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/protos/server_farm.job"
	jobStateProtos "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/protos/server_farm.mq.job_state_exchange"
	quotas "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/quotas"
	"github.com/semaphoreio/semaphore/self_hosted_hub/pkg/workers/agentcounter"
	"google.golang.org/protobuf/proto"

	require "github.com/stretchr/testify/require"

	grpcmock "github.com/semaphoreio/semaphore/self_hosted_hub/test/grpcmock"
)

var testOrgID, _ = uuid.Parse(uuid.NewString())
var testRequesterID = database.UUID()
var featureHubProvider, _ = feature.NewFeatureHubProvider("0.0.0.0:50052")
var quotaClient, _ = quotas.NewQuotaClient(featureHubProvider)
var agentCounterInterval = 200 * time.Millisecond
var agentCounter, _ = agentcounter.NewAgentCounter(&agentCounterInterval)
var publisher, _ = amqp.NewPublisher("amqp://guest:guest@rabbitmq:5672")
var testServer, _ = NewServer(quotaClient, agentCounter, publisher)

func Test__HealthCheckEndpointRespondsWith200(t *testing.T) {
	request, _ := http.NewRequest("GET", "/", nil)
	response := httptest.NewRecorder()
	testServer.Router.ServeHTTP(response, request)
	require.Equal(t, response.Code, 200)
}

func Test__Audit(t *testing.T) {
	database.TruncateTables()
	grpcmock.Start()

	agentType, token, _ := newAgentType("s1-test")

	t.Run("event is sent when agent registers", func(t *testing.T) {
		_ = declareExchangeAndQueue()
		agentName := "hello"
		res := run("POST", "/register", token, registerRequest(agentName))
		require.Equal(t, http.StatusCreated, res.Code)

		checkAuditEventReceived(t, agentName, auditProtos.Event_Added)
		_ = purgeExchangeAndQueue()
	})

	t.Run("event is not sent on register if requester_id is empty", func(t *testing.T) {
		_ = declareExchangeAndQueue()

		_, noReqToken, _ := models.CreateAgentType(testOrgID, nil, "s1-test-no-requester")
		res := run("POST", "/register", noReqToken, registerRequest("hello2"))
		require.Equal(t, http.StatusCreated, res.Code)

		checkNoAuditEventReceived(t)
		_ = purgeExchangeAndQueue()
	})

	t.Run("event is not sent on register error", func(t *testing.T) {
		_ = declareExchangeAndQueue()
		agentName := "hello3"
		res := run("POST", "/register", "bad-token", registerRequest(agentName))
		require.Equal(t, http.StatusNotFound, res.Code)

		checkNoAuditEventReceived(t)
		_ = purgeExchangeAndQueue()
	})

	t.Run("event is sent when agent disconnects", func(t *testing.T) {
		_ = declareExchangeAndQueue()
		agent, agentToken, err := newAgent(agentType)
		require.Nil(t, err)

		res := run("POST", "/disconnect", agentToken, nil)
		require.Equal(t, http.StatusOK, res.Code)

		checkAuditEventReceived(t, agent.Name, auditProtos.Event_Removed)
		_ = purgeExchangeAndQueue()
	})

	t.Run("event is not sent on disconnect if requester_id is empty", func(t *testing.T) {
		_ = declareExchangeAndQueue()

		noReqAgentType, _, _ := models.CreateAgentType(testOrgID, nil, "s1-test-no-requester-2")
		_, noReqAgentToken, err := newAgent(noReqAgentType)
		require.Nil(t, err)

		res := run("POST", "/disconnect", noReqAgentToken, nil)
		require.Equal(t, http.StatusOK, res.Code)

		checkNoAuditEventReceived(t)
		_ = purgeExchangeAndQueue()
	})

	t.Run("event is not sent on disconnect error", func(t *testing.T) {
		_ = declareExchangeAndQueue()
		res := run("POST", "/disconnect", "agent-does-not-exist", nil)
		require.Equal(t, http.StatusNotFound, res.Code)

		checkNoAuditEventReceived(t)
		_ = purgeExchangeAndQueue()
	})
}

func Test__SyncEnforcesQuotas(t *testing.T) {
	database.TruncateTables()
	grpcmock.Start()

	agentType, _, err := newAgentType("s1-test")
	require.Nil(t, err)

	t.Run("feature disabled => all agents are disconnected", func(t *testing.T) {
		os.Setenv("SELF_HOSTED_QUOTAS", "")
		quotaClient.Clear(testOrgID.String())

		// agents can register
		a1, a1Token, _ := newAgent(agentType)
		sync(t, syncAssertion{
			state:  agentsync.AgentStateWaitingForJobs,
			token:  a1Token,
			action: agentsync.AgentActionContinue,
		})

		a2, a2Token, _ := newAgent(agentType)
		sync(t, syncAssertion{
			state:  agentsync.AgentStateWaitingForJobs,
			token:  a2Token,
			action: agentsync.AgentActionContinue,
		})

		// feature is disabled for organization
		os.Setenv("SELF_HOSTED_QUOTAS", "disabled")
		quotaClient.Clear(testOrgID.String())

		// all agents are told to shutdown
		sync(t, syncAssertion{
			state:          agentsync.AgentStateWaitingForJobs,
			token:          a1Token,
			action:         agentsync.AgentActionShutdown,
			shutdownReason: agentsync.ShutdownReasonRequested,
		})

		sync(t, syncAssertion{
			state:          agentsync.AgentStateWaitingForJobs,
			token:          a2Token,
			action:         agentsync.AgentActionShutdown,
			shutdownReason: agentsync.ShutdownReasonRequested,
		})

		require.Nil(t, a1.Disconnect())
		require.Nil(t, a2.Disconnect())

		os.Setenv("SELF_HOSTED_QUOTAS", "")
		quotaClient.Clear(testOrgID.String())
	})

	t.Run("quota decrease => some agents are disconnected", func(t *testing.T) {
		os.Setenv("SELF_HOSTED_QUOTAS", "")
		quotaClient.Clear(testOrgID.String())

		// agents can register
		a1, a1Token, _ := newAgent(agentType)
		sync(t, syncAssertion{
			state:  agentsync.AgentStateWaitingForJobs,
			token:  a1Token,
			action: agentsync.AgentActionContinue,
		})

		a2, a2Token, _ := newAgent(agentType)
		sync(t, syncAssertion{
			state:  agentsync.AgentStateWaitingForJobs,
			token:  a2Token,
			action: agentsync.AgentActionContinue,
		})

		// quotas are decreased, wait a bit for agent counter to refresh itself
		os.Setenv("SELF_HOSTED_QUOTAS", "1")
		quotaClient.Clear(testOrgID.String())
		time.Sleep(2 * agentCounterInterval)

		// just one agent is told to shut down
		sync(t, syncAssertion{
			state:          agentsync.AgentStateWaitingForJobs,
			token:          a1Token,
			action:         agentsync.AgentActionShutdown,
			shutdownReason: agentsync.ShutdownReasonRequested,
		})

		sync(t, syncAssertion{
			state:  agentsync.AgentStateWaitingForJobs,
			token:  a2Token,
			action: agentsync.AgentActionContinue,
		})

		require.Nil(t, a1.Disconnect())
		require.Nil(t, a2.Disconnect())

		os.Setenv("SELF_HOSTED_QUOTAS", "")
		quotaClient.Clear(testOrgID.String())
	})
}

func Test__Sync(t *testing.T) {
	database.TruncateTables()

	agentType, _, err := newAgentType("s1-test")
	require.Nil(t, err)

	t.Run("responds with 404 for unknown agent", func(t *testing.T) {
		req := &agentsync.Request{State: agentsync.AgentStateWaitingForJobs, JobID: ""}
		res := run("POST", "/sync", "token-does-not-exist", req)
		require.Equal(t, http.StatusNotFound, res.Code)
	})

	t.Run("responds with 200", func(t *testing.T) {
		agent, token, err := newAgent(agentType)
		require.Nil(t, err)

		req := &agentsync.Request{State: agentsync.AgentStateWaitingForJobs, JobID: ""}
		res := run("POST", "/sync", token, req)
		require.Equal(t, http.StatusOK, res.Code)
		require.Nil(t, agent.Disconnect())
	})

	t.Run("continues waiting if not interrupted", func(t *testing.T) {
		agent, token, err := newAgent(agentType)
		require.Nil(t, err)

		// waiting-for-jobs => continue
		sync(t, syncAssertion{
			state:  agentsync.AgentStateWaitingForJobs,
			token:  token,
			action: agentsync.AgentActionContinue,
		})

		agent, err = models.FindAgentByToken(testOrgID.String(), agent.TokenHash)
		require.Nil(t, err)
		require.Nil(t, agent.InterruptedAt)
		require.Nil(t, agent.Disconnect())
	})

	t.Run("shuts down if interrupted while waiting", func(t *testing.T) {
		agent, token, err := newAgent(agentType)
		require.Nil(t, err)

		// waiting-for-jobs => shutdown(interrupted)
		now := time.Now().Unix()
		sync(t, syncAssertion{
			state:          agentsync.AgentStateWaitingForJobs,
			token:          token,
			action:         agentsync.AgentActionShutdown,
			shutdownReason: agentsync.ShutdownReasonInterrupted,
			interruptedAt:  now,
		})

		agent, err = models.FindAgentByToken(testOrgID.String(), agent.TokenHash)
		require.Nil(t, err)
		require.NotNil(t, agent.InterruptedAt)
		require.Nil(t, agent.Disconnect())
	})

	t.Run("interrupted while running job => stops job immediately if no grace period", func(t *testing.T) {
		_ = declareExchangeAndQueue()
		agent, token, err := newAgent(agentType)
		require.Nil(t, err)

		// waiting-for-jobs => continue
		sync(t, syncAssertion{
			state:  agentsync.AgentStateWaitingForJobs,
			token:  token,
			action: agentsync.AgentActionContinue,
		})

		// new occupation request comes in
		jobId := database.UUID()
		models.CreateOccupationRequest(testOrgID, agentType.Name, jobId)

		// waiting-for-jobs => run-job
		sync(t, syncAssertion{
			state:           agentsync.AgentStateWaitingForJobs,
			token:           token,
			action:          agentsync.AgentActionRunJob,
			jobIdOnRequest:  "",
			jobIdOnResponse: jobId.String(),
		})

		// running-job with interruptedAt set => stop-job
		now := time.Now().Unix()
		sync(t, syncAssertion{
			state:           agentsync.AgentStateRunningJob,
			token:           token,
			interruptedAt:   now,
			action:          agentsync.AgentActionStopJob,
			jobIdOnRequest:  jobId.String(),
			jobIdOnResponse: jobId.String(),
		})

		// finished-job => shutdown
		sync(t, syncAssertion{
			state:          agentsync.AgentStateFinishedJob,
			token:          token,
			action:         agentsync.AgentActionShutdown,
			jobIdOnRequest: jobId.String(),
			jobResult:      agentsync.JobResultStopped,
			shutdownReason: agentsync.ShutdownReasonInterrupted,
		})

		checkFinishedEventReceived(t, jobId.String(), agentsync.JobResultStopped)
		checkTeardownFinishedEventReceived(t, jobId.String())
		_ = purgeExchangeAndQueue()
		require.Nil(t, agent.Disconnect())
	})

	t.Run("interrupted while running job => waits for grace period", func(t *testing.T) {
		_ = declareExchangeAndQueue()

		// 2 seconds of grace period
		agent, token, err := newAgentWithMetadata(agentType, models.AgentMetadata{InterruptionGracePeriod: 2})
		require.Nil(t, err)

		// waiting-for-jobs => continue
		sync(t, syncAssertion{
			state:  agentsync.AgentStateWaitingForJobs,
			token:  token,
			action: agentsync.AgentActionContinue,
		})

		// new occupation request comes in
		jobId := database.UUID()
		models.CreateOccupationRequest(testOrgID, agentType.Name, jobId)

		// waiting-for-jobs => run-job
		sync(t, syncAssertion{
			state:           agentsync.AgentStateWaitingForJobs,
			token:           token,
			action:          agentsync.AgentActionRunJob,
			jobIdOnRequest:  "",
			jobIdOnResponse: jobId.String(),
		})

		// running-job with interruptedAt set, but grace period still not reached => continue
		interruptedAt := time.Now().Unix()
		sync(t, syncAssertion{
			state:          agentsync.AgentStateRunningJob,
			token:          token,
			interruptedAt:  interruptedAt,
			action:         agentsync.AgentActionContinue,
			jobIdOnRequest: jobId.String(),
		})

		time.Sleep(3 * time.Second)

		// running-job, grace period reached => stop-job
		sync(t, syncAssertion{
			state:           agentsync.AgentStateRunningJob,
			token:           token,
			interruptedAt:   interruptedAt,
			action:          agentsync.AgentActionStopJob,
			jobIdOnRequest:  jobId.String(),
			jobIdOnResponse: jobId.String(),
		})

		// finished-job => shutdown
		sync(t, syncAssertion{
			state:          agentsync.AgentStateFinishedJob,
			token:          token,
			action:         agentsync.AgentActionShutdown,
			interruptedAt:  interruptedAt,
			jobIdOnRequest: jobId.String(),
			jobResult:      agentsync.JobResultStopped,
			shutdownReason: agentsync.ShutdownReasonInterrupted,
		})

		checkFinishedEventReceived(t, jobId.String(), agentsync.JobResultStopped)
		checkTeardownFinishedEventReceived(t, jobId.String())
		_ = purgeExchangeAndQueue()
		require.Nil(t, agent.Disconnect())
	})

	t.Run("interrupted while running job => finishes job and shuts down", func(t *testing.T) {
		_ = declareExchangeAndQueue()

		// 10 seconds of grace period
		agent, token, err := newAgentWithMetadata(agentType, models.AgentMetadata{InterruptionGracePeriod: 10})
		require.Nil(t, err)

		// waiting-for-jobs => continue
		sync(t, syncAssertion{
			state:  agentsync.AgentStateWaitingForJobs,
			token:  token,
			action: agentsync.AgentActionContinue,
		})

		// new occupation request comes in
		jobId := database.UUID()
		models.CreateOccupationRequest(testOrgID, agentType.Name, jobId)

		// waiting-for-jobs => run-job
		sync(t, syncAssertion{
			state:           agentsync.AgentStateWaitingForJobs,
			token:           token,
			action:          agentsync.AgentActionRunJob,
			jobIdOnRequest:  "",
			jobIdOnResponse: jobId.String(),
		})

		time.Sleep(3 * time.Second)

		// running-job with interruptedAt set, but grace period still not reached => continue
		interruptedAt := time.Now().Unix()
		sync(t, syncAssertion{
			state:          agentsync.AgentStateRunningJob,
			token:          token,
			interruptedAt:  interruptedAt,
			action:         agentsync.AgentActionContinue,
			jobIdOnRequest: jobId.String(),
		})

		// finished-job => shutdown
		sync(t, syncAssertion{
			state:          agentsync.AgentStateFinishedJob,
			token:          token,
			action:         agentsync.AgentActionShutdown,
			interruptedAt:  interruptedAt,
			jobIdOnRequest: jobId.String(),
			jobResult:      agentsync.JobResultPassed,
			shutdownReason: agentsync.ShutdownReasonInterrupted,
		})

		checkFinishedEventReceived(t, jobId.String(), agentsync.JobResultPassed)
		checkTeardownFinishedEventReceived(t, jobId.String())
		_ = purgeExchangeAndQueue()
		require.Nil(t, agent.Disconnect())
	})

	t.Run("disabled while running job => stops job before shutting down", func(t *testing.T) {
		_ = declareExchangeAndQueue()
		agent, token, err := newAgent(agentType)
		require.Nil(t, err)

		// waiting-for-jobs => continue
		sync(t, syncAssertion{
			state:  agentsync.AgentStateWaitingForJobs,
			token:  token,
			action: agentsync.AgentActionContinue,
		})

		// new occupation request comes in
		jobId := database.UUID()
		models.CreateOccupationRequest(testOrgID, agentType.Name, jobId)

		// waiting-for-jobs => run-job
		sync(t, syncAssertion{
			state:           agentsync.AgentStateWaitingForJobs,
			token:           token,
			action:          agentsync.AgentActionRunJob,
			jobIdOnRequest:  "",
			jobIdOnResponse: jobId.String(),
		})

		// agent is disabled
		_, err = models.DisableAgent(testOrgID, agentType.Name, agent.Name)
		require.Nil(t, err)

		// running-job => stop-job
		sync(t, syncAssertion{
			state:           agentsync.AgentStateRunningJob,
			token:           token,
			action:          agentsync.AgentActionStopJob,
			jobIdOnRequest:  jobId.String(),
			jobIdOnResponse: jobId.String(),
		})

		// finished-job => shutdown
		sync(t, syncAssertion{
			state:          agentsync.AgentStateFinishedJob,
			token:          token,
			action:         agentsync.AgentActionShutdown,
			jobIdOnRequest: jobId.String(),
			jobResult:      agentsync.JobResultStopped,
			shutdownReason: agentsync.ShutdownReasonRequested,
		})

		checkFinishedEventReceived(t, jobId.String(), agentsync.JobResultStopped)
		checkTeardownFinishedEventReceived(t, jobId.String())
		_ = purgeExchangeAndQueue()
		require.Nil(t, agent.Disconnect())
	})

	t.Run("disabled while idle => shut down right away", func(t *testing.T) {
		agent, token, err := newAgent(agentType)
		require.Nil(t, err)

		// waiting-for-jobs => continue
		sync(t, syncAssertion{
			state:  agentsync.AgentStateWaitingForJobs,
			token:  token,
			action: agentsync.AgentActionContinue,
		})

		_, err = models.DisableAgent(testOrgID, agentType.Name, agent.Name)
		require.Nil(t, err)

		// waiting-for-jobs => shutdown
		sync(t, syncAssertion{
			state:          agentsync.AgentStateWaitingForJobs,
			token:          token,
			action:         agentsync.AgentActionShutdown,
			shutdownReason: agentsync.ShutdownReasonRequested,
		})

		require.Nil(t, agent.Disconnect())
	})

	t.Run("job stopped when single_job=false => stops job and waits for more jobs", func(t *testing.T) {
		_ = declareExchangeAndQueue()
		agent, token, err := newAgent(agentType)
		require.Nil(t, err)

		// waiting-for-jobs => continue
		sync(t, syncAssertion{
			state:  agentsync.AgentStateWaitingForJobs,
			token:  token,
			action: agentsync.AgentActionContinue,
		})

		// new occupation request comes in
		jobId := database.UUID()
		models.CreateOccupationRequest(testOrgID, agentType.Name, jobId)

		// waiting-for-jobs => run-job
		sync(t, syncAssertion{
			state:           agentsync.AgentStateWaitingForJobs,
			token:           token,
			action:          agentsync.AgentActionRunJob,
			jobIdOnRequest:  "",
			jobIdOnResponse: jobId.String(),
		})

		// job is stopped
		err = models.StopJob(testOrgID, jobId)
		require.Nil(t, err)

		// running-job => stop-job
		sync(t, syncAssertion{
			state:           agentsync.AgentStateRunningJob,
			token:           token,
			action:          agentsync.AgentActionStopJob,
			jobIdOnRequest:  jobId.String(),
			jobIdOnResponse: jobId.String(),
		})

		// finished-job => waiting-for-jobs
		sync(t, syncAssertion{
			state:          agentsync.AgentStateFinishedJob,
			token:          token,
			action:         agentsync.AgentActionWaitForJobs,
			jobIdOnRequest: jobId.String(),
			jobResult:      agentsync.JobResultStopped,
		})

		checkFinishedEventReceived(t, jobId.String(), agentsync.JobResultStopped)
		checkTeardownFinishedEventReceived(t, jobId.String())
		_ = purgeExchangeAndQueue()
		require.Nil(t, agent.Disconnect())
	})

	t.Run("job stopped when single_job=true => stops job and shuts down", func(t *testing.T) {
		_ = declareExchangeAndQueue()
		agent, token, err := newAgentWithMetadata(agentType, models.AgentMetadata{SingleJob: true})
		require.Nil(t, err)

		// waiting-for-jobs => continue
		sync(t, syncAssertion{
			state:  agentsync.AgentStateWaitingForJobs,
			token:  token,
			action: agentsync.AgentActionContinue,
		})

		// new occupation request comes in
		jobId := database.UUID()
		models.CreateOccupationRequest(testOrgID, agentType.Name, jobId)

		// waiting-for-jobs => run-job
		sync(t, syncAssertion{
			state:           agentsync.AgentStateWaitingForJobs,
			token:           token,
			action:          agentsync.AgentActionRunJob,
			jobIdOnResponse: jobId.String(),
		})

		// job is stopped
		err = models.StopJob(testOrgID, jobId)
		require.Nil(t, err)

		// running-job => stop-job
		sync(t, syncAssertion{
			state:           agentsync.AgentStateRunningJob,
			token:           token,
			action:          agentsync.AgentActionStopJob,
			jobIdOnRequest:  jobId.String(),
			jobIdOnResponse: jobId.String(),
		})

		// finished-job => shut-down
		sync(t, syncAssertion{
			state:          agentsync.AgentStateFinishedJob,
			token:          token,
			action:         agentsync.AgentActionShutdown,
			jobIdOnRequest: jobId.String(),
			jobResult:      agentsync.JobResultStopped,
			shutdownReason: agentsync.ShutdownReasonJobFinished,
		})

		checkFinishedEventReceived(t, jobId.String(), agentsync.JobResultStopped)
		checkTeardownFinishedEventReceived(t, jobId.String())
		_ = purgeExchangeAndQueue()
		require.Nil(t, agent.Disconnect())
	})

	t.Run("finished-job => agent with single_job=false is released and waits for more jobs", func(t *testing.T) {
		_ = declareExchangeAndQueue()
		agent, token, err := newAgent(agentType)
		require.Nil(t, err)

		// waiting-for-jobs => continue
		sync(t, syncAssertion{
			state:  agentsync.AgentStateWaitingForJobs,
			token:  token,
			action: agentsync.AgentActionContinue,
		})

		// new occupation request comes in
		jobId := database.UUID()
		models.CreateOccupationRequest(testOrgID, agentType.Name, jobId)

		// waiting-for-jobs => run-job
		sync(t, syncAssertion{
			state:           agentsync.AgentStateWaitingForJobs,
			token:           token,
			action:          agentsync.AgentActionRunJob,
			jobIdOnResponse: jobId.String(),
		})

		// running-job => continue
		sync(t, syncAssertion{
			state:          agentsync.AgentStateRunningJob,
			token:          token,
			action:         agentsync.AgentActionContinue,
			jobIdOnRequest: jobId.String(),
		})

		// finished-job => wait-for-jobs
		sync(t, syncAssertion{
			state:          agentsync.AgentStateFinishedJob,
			token:          token,
			action:         agentsync.AgentActionWaitForJobs,
			jobIdOnRequest: jobId.String(),
			jobResult:      agentsync.JobResultPassed,
		})

		checkFinishedEventReceived(t, jobId.String(), agentsync.JobResultPassed)
		checkTeardownFinishedEventReceived(t, jobId.String())
		_ = purgeExchangeAndQueue()
		require.Nil(t, agent.Disconnect())
	})

	t.Run("finished-job => agent with single_job=true is not released and shuts down", func(t *testing.T) {
		_ = declareExchangeAndQueue()
		agent, token, err := newAgentWithMetadata(agentType, models.AgentMetadata{SingleJob: true})
		require.Nil(t, err)

		// waiting-for-jobs => continue
		sync(t, syncAssertion{
			state:  agentsync.AgentStateWaitingForJobs,
			token:  token,
			action: agentsync.AgentActionContinue,
		})

		// new occupation request comes in
		jobId := database.UUID()
		models.CreateOccupationRequest(testOrgID, agentType.Name, jobId)

		// waiting-for-jobs => run-job
		sync(t, syncAssertion{
			state:           agentsync.AgentStateWaitingForJobs,
			token:           token,
			action:          agentsync.AgentActionRunJob,
			jobIdOnResponse: jobId.String(),
		})

		// running-job => continue
		sync(t, syncAssertion{
			state:          agentsync.AgentStateRunningJob,
			token:          token,
			action:         agentsync.AgentActionContinue,
			jobIdOnRequest: jobId.String(),
		})

		// finished-job => shut-down
		sync(t, syncAssertion{
			state:          agentsync.AgentStateFinishedJob,
			token:          token,
			action:         agentsync.AgentActionShutdown,
			jobIdOnRequest: jobId.String(),
			jobResult:      agentsync.JobResultPassed,
			shutdownReason: agentsync.ShutdownReasonJobFinished,
		})

		// assert agent is not released
		agent, err = models.FindAgentByToken(testOrgID.String(), agent.TokenHash)
		require.Nil(t, err)
		require.Equal(t, jobId, *agent.AssignedJobID)

		checkFinishedEventReceived(t, jobId.String(), agentsync.JobResultPassed)
		checkTeardownFinishedEventReceived(t, jobId.String())
		_ = purgeExchangeAndQueue()
		require.Nil(t, agent.Disconnect())
	})

	// This test makes sure backwards compatibility with the deprecated callback broker models works.
	// We can remove it once we are sure no more old agents are being registered.
	t.Run("finished-job => already released agent leads waits for jobs", func(t *testing.T) {
		_ = declareExchangeAndQueue()
		agent, token, err := newAgent(agentType)
		require.Nil(t, err)

		// waiting-for-jobs => continue
		sync(t, syncAssertion{
			state:  agentsync.AgentStateWaitingForJobs,
			token:  token,
			action: agentsync.AgentActionContinue,
		})

		// new occupation request comes in
		jobId := database.UUID()
		models.CreateOccupationRequest(testOrgID, agentType.Name, jobId)

		// waiting-for-jobs => run-job
		sync(t, syncAssertion{
			state:           agentsync.AgentStateWaitingForJobs,
			token:           token,
			action:          agentsync.AgentActionRunJob,
			jobIdOnResponse: jobId.String(),
		})

		// running-job => continue
		sync(t, syncAssertion{
			state:          agentsync.AgentStateRunningJob,
			token:          token,
			action:         agentsync.AgentActionContinue,
			jobIdOnRequest: jobId.String(),
		})

		// This simulates a ReleaseAgent() call coming from Zebra
		_, err = models.ReleaseAgent(testOrgID, agent.AgentTypeName, jobId)
		require.Nil(t, err)

		// finished-job => wait-for-jobs
		sync(t, syncAssertion{
			state:          agentsync.AgentStateFinishedJob,
			token:          token,
			action:         agentsync.AgentActionWaitForJobs,
			jobIdOnRequest: jobId.String(),
		})

		checkNoFinishedEventReceived(t)
		checkNoTeardownFinishedEventReceived(t)
		_ = purgeExchangeAndQueue()
		require.Nil(t, agent.Disconnect())
	})

	t.Run("finished-job => agent disabled leads shuts down", func(t *testing.T) {
		_ = declareExchangeAndQueue()
		agent, token, err := newAgent(agentType)
		require.Nil(t, err)

		// waiting-for-jobs => continue
		sync(t, syncAssertion{
			state:  agentsync.AgentStateWaitingForJobs,
			token:  token,
			action: agentsync.AgentActionContinue,
		})

		// new occupation request comes in
		jobId := database.UUID()
		models.CreateOccupationRequest(testOrgID, agentType.Name, jobId)

		// waiting-for-jobs => run-job
		sync(t, syncAssertion{
			state:           agentsync.AgentStateWaitingForJobs,
			token:           token,
			action:          agentsync.AgentActionRunJob,
			jobIdOnResponse: jobId.String(),
		})

		// running-job => continue
		sync(t, syncAssertion{
			state:          agentsync.AgentStateRunningJob,
			token:          token,
			action:         agentsync.AgentActionContinue,
			jobIdOnRequest: jobId.String(),
		})

		// This simulates an agent being disabled through the UI
		_, err = models.DisableAgent(testOrgID, agent.AgentTypeName, agent.Name)
		require.Nil(t, err)

		// finished-job => shut-down
		sync(t, syncAssertion{
			state:          agentsync.AgentStateFinishedJob,
			token:          token,
			action:         agentsync.AgentActionShutdown,
			jobIdOnRequest: jobId.String(),
			jobResult:      agentsync.JobResultFailed,
			shutdownReason: agentsync.ShutdownReasonRequested,
		})

		checkFinishedEventReceived(t, jobId.String(), agentsync.JobResultFailed)
		checkTeardownFinishedEventReceived(t, jobId.String())
		_ = purgeExchangeAndQueue()
		require.Nil(t, agent.Disconnect())
	})

	t.Run("starting-job => continue", func(t *testing.T) {
		agent, token, err := newAgent(agentType)
		require.Nil(t, err)

		// waiting-for-jobs => continue
		sync(t, syncAssertion{
			state:  agentsync.AgentStateWaitingForJobs,
			token:  token,
			action: agentsync.AgentActionContinue,
		})

		// new occupation request comes in
		jobId := database.UUID()
		models.CreateOccupationRequest(testOrgID, agentType.Name, jobId)

		// waiting-for-jobs => run-job
		sync(t, syncAssertion{
			state:           agentsync.AgentStateWaitingForJobs,
			token:           token,
			action:          agentsync.AgentActionRunJob,
			jobIdOnResponse: jobId.String(),
		})

		// starting-job => continue
		sync(t, syncAssertion{
			state:          agentsync.AgentStateStartingJob,
			token:          token,
			action:         agentsync.AgentActionContinue,
			jobIdOnRequest: jobId.String(),
		})

		require.Nil(t, agent.Disconnect())
	})

	t.Run("stopping-job => continue", func(t *testing.T) {
		agent, token, err := newAgent(agentType)
		require.Nil(t, err)

		// waiting-for-jobs => continue
		sync(t, syncAssertion{
			state:  agentsync.AgentStateWaitingForJobs,
			token:  token,
			action: agentsync.AgentActionContinue,
		})

		// new occupation request comes in
		jobId := database.UUID()
		models.CreateOccupationRequest(testOrgID, agentType.Name, jobId)

		// waiting-for-jobs => run-job
		sync(t, syncAssertion{
			state:           agentsync.AgentStateWaitingForJobs,
			token:           token,
			action:          agentsync.AgentActionRunJob,
			jobIdOnResponse: jobId.String(),
		})

		// job is stopped
		err = models.StopJob(testOrgID, jobId)
		require.Nil(t, err)

		// running-job => stop-job
		sync(t, syncAssertion{
			state:           agentsync.AgentStateRunningJob,
			token:           token,
			action:          agentsync.AgentActionStopJob,
			jobIdOnRequest:  jobId.String(),
			jobIdOnResponse: jobId.String(),
		})

		// stopping-job => continue
		sync(t, syncAssertion{
			state:          agentsync.AgentStateStoppingJob,
			token:          token,
			action:         agentsync.AgentActionContinue,
			jobIdOnRequest: jobId.String(),
		})

		require.Nil(t, agent.Disconnect())
	})

	t.Run("agent with no idle timeout does not shut down", func(t *testing.T) {
		agent, token, err := newAgent(agentType)
		require.Nil(t, err)

		// waiting-for-jobs => continue
		sync(t, syncAssertion{
			state:  agentsync.AgentStateWaitingForJobs,
			token:  token,
			action: agentsync.AgentActionContinue,
		})

		// waiting-for-jobs => continue
		time.Sleep(3 * time.Second)
		sync(t, syncAssertion{
			state:  agentsync.AgentStateWaitingForJobs,
			token:  token,
			action: agentsync.AgentActionContinue,
		})

		// waiting-for-jobs => continue
		time.Sleep(3 * time.Second)
		sync(t, syncAssertion{
			state:  agentsync.AgentStateWaitingForJobs,
			token:  token,
			action: agentsync.AgentActionContinue,
		})

		require.Nil(t, agent.Disconnect())
	})

	t.Run("idle agent shuts down after timeout", func(t *testing.T) {
		agent, token, err := newAgentWithMetadata(agentType, models.AgentMetadata{IdleTimeout: 5})
		require.Nil(t, err)

		// waiting-for-jobs => continue
		sync(t, syncAssertion{
			state:  agentsync.AgentStateWaitingForJobs,
			token:  token,
			action: agentsync.AgentActionContinue,
		})

		time.Sleep(3 * time.Second)

		// still not idle enough
		// waiting-for-jobs => continue
		sync(t, syncAssertion{
			state:  agentsync.AgentStateWaitingForJobs,
			token:  token,
			action: agentsync.AgentActionContinue,
		})

		time.Sleep(3 * time.Second)

		// 6s of idleness
		// waiting-for-jobs => shutdown
		sync(t, syncAssertion{
			state:          agentsync.AgentStateWaitingForJobs,
			token:          token,
			action:         agentsync.AgentActionShutdown,
			shutdownReason: agentsync.ShutdownReasonIdle,
		})

		require.Nil(t, agent.Disconnect())
	})

	t.Run("idle agent assigned to job just before sync runs job", func(t *testing.T) {
		agent, token, err := newAgentWithMetadata(agentType, models.AgentMetadata{IdleTimeout: 5})
		require.Nil(t, err)

		// waiting-for-jobs => continue
		sync(t, syncAssertion{
			state:  agentsync.AgentStateWaitingForJobs,
			token:  token,
			action: agentsync.AgentActionContinue,
		})

		time.Sleep(4 * time.Second)

		// still not idle enough
		// waiting-for-jobs => continue
		sync(t, syncAssertion{
			state:  agentsync.AgentStateWaitingForJobs,
			token:  token,
			action: agentsync.AgentActionContinue,
		})

		// new occupation request comes in just before new sync that would shut down agent
		jobId := database.UUID()
		models.CreateOccupationRequest(testOrgID, agentType.Name, jobId)

		// 6s of idleness, but job was assigned, so agent should run job
		// waiting-for-jobs => run-job
		time.Sleep(2 * time.Second)
		sync(t, syncAssertion{
			state:           agentsync.AgentStateWaitingForJobs,
			token:           token,
			action:          agentsync.AgentActionRunJob,
			jobIdOnResponse: jobId.String(),
		})

		require.Nil(t, agent.Disconnect())
	})

	/*
	 * Make sure we assert that old agents (those still using the job callback broker),
	 * still can be understood when sending these deprecated old failed states.
	 * We can remove this test when we are sure no more old agents are being used.
	 */
	t.Run("failed states are handled as job-finished", func(t *testing.T) {
		_ = declareExchangeAndQueue()
		_, token, err := newAgent(agentType)
		require.Nil(t, err)

		// new occupation request comes in
		jobId := database.UUID()
		models.CreateOccupationRequest(testOrgID, agentType.Name, jobId)

		// waiting-for-jobs => run-job
		sync(t, syncAssertion{
			state:           agentsync.AgentStateWaitingForJobs,
			token:           token,
			action:          agentsync.AgentActionRunJob,
			jobIdOnResponse: jobId.String(),
		})

		// failed-to-fetch-job => wait-for-jobs
		sync(t, syncAssertion{
			state:  agentsync.AgentStateFailedToFetchJob,
			token:  token,
			action: agentsync.AgentActionWaitForJobs,
		})

		checkFinishedEventReceived(t, jobId.String(), agentsync.JobResultFailed)
		checkTeardownFinishedEventReceived(t, jobId.String())
		_ = purgeExchangeAndQueue()
	})
}

func Test__DescribeJob(t *testing.T) {
	database.TruncateTables()
	grpcmock.Start()

	agentType, _, err := newAgentType("s1-test")
	require.Nil(t, err)

	agent, token, err := newAgent(agentType)
	require.Nil(t, err)

	t.Run("when the job is not yet assigned to the agent", func(t *testing.T) {
		someJobID := database.UUID()
		res := run("GET", "/jobs/"+someJobID.String(), token, nil)

		require.Equal(t, http.StatusNotFound, res.Code)
	})

	t.Run("when the job is assigned to the agent", func(t *testing.T) {
		jobID, _ := models.ForcefullyOccupyAgentWithJobID(agent)
		res := run("GET", "/jobs/"+jobID.String(), token, nil)

		require.Equal(t, http.StatusOK, res.Code)
	})
}

func Test__ListJobs(t *testing.T) {
	database.TruncateTables()
	grpcmock.Start()

	t.Run("when agent type does not exist", func(t *testing.T) {
		res := run("GET", "/jobs", "invalid-token", nil)
		require.Equal(t, http.StatusNotFound, res.Code)
	})

	t.Run("when agent type exists", func(t *testing.T) {
		agentType, token, err := newAgentType("s1-test")
		require.Nil(t, err)

		// Create some jobs in the database
		jobID1 := database.UUID()
		jobID2 := database.UUID()
		jobID3 := database.UUID()

		// Mock the zebra client response
		grpcmock.MockListJobsResponse(agentType.OrganizationID.String(), agentType.Name, []*zebrapb.Job{
			{Id: jobID1.String()},
			{Id: jobID2.String()},
			{Id: jobID3.String()},
		})

		res := run("GET", "/jobs", token, nil)
		require.Equal(t, http.StatusOK, res.Code)

		var response ListJobsResponse
		err = unmarshalJSON(res.Body, &response)
		require.Nil(t, err)
		require.Len(t, response.Jobs, 3)
		require.Equal(t, jobID1.String(), response.Jobs[0].ID)
		require.Equal(t, jobID2.String(), response.Jobs[1].ID)
		require.Equal(t, jobID3.String(), response.Jobs[2].ID)
	})

	t.Run("when zebra client returns an error", func(t *testing.T) {
		agentType, token, err := newAgentType("s1-test-error")
		require.Nil(t, err)

		// Mock zebra client error
		grpcmock.MockListJobsError(agentType.OrganizationID.String(), agentType.Name)

		res := run("GET", "/jobs", token, nil)
		require.Equal(t, http.StatusInternalServerError, res.Code)
	})

	t.Run("when no jobs are available", func(t *testing.T) {
		agentType, token, err := newAgentType("s1-test-empty")
		require.Nil(t, err)

		// Mock empty response
		grpcmock.MockListJobsResponse(agentType.OrganizationID.String(), agentType.Name, []*zebrapb.Job{})

		res := run("GET", "/jobs", token, nil)
		require.Equal(t, http.StatusOK, res.Code)

		var response ListJobsResponse
		err = unmarshalJSON(res.Body, &response)
		require.Nil(t, err)
		require.Empty(t, response.Jobs)
	})
}

func Test__Disconnect(t *testing.T) {
	database.TruncateTables()

	t.Run("agent not found", func(t *testing.T) {
		token := "some-rangod-token-not-connected-to-an-agent"
		res := run("POST", "/disconnect", token, nil)
		require.Equal(t, http.StatusNotFound, res.Code)
	})

	t.Run("agent found and disconnected", func(t *testing.T) {
		agentType, _, err := newAgentType("s1-test")
		require.Nil(t, err)

		agent, token, err := newAgent(agentType)
		require.Nil(t, err)

		res := run("POST", "/disconnect", token, nil)
		require.Equal(t, http.StatusOK, res.Code)

		_, err = models.FindAgentByToken(agent.OrganizationID.String(), agent.TokenHash)
		require.Equal(t, err.Error(), "record not found")
	})
}

func Test__RefreshToken(t *testing.T) {
	database.TruncateTables()

	t.Run("agent not found", func(t *testing.T) {
		token := "token-not-connected-to-an-agent"
		res := run("POST", "/refresh", token, nil)

		require.Equal(t, http.StatusNotFound, res.Code)
	})

	t.Run("agent found but has no assigned job", func(t *testing.T) {
		agentType, _, err := newAgentType("s1-test")
		require.Nil(t, err)

		_, token, err := newAgent(agentType)
		require.Nil(t, err)

		res := run("POST", "/refresh", token, nil)
		require.Equal(t, http.StatusUnprocessableEntity, res.Code)
	})

	t.Run("agent found and has job assigned", func(t *testing.T) {
		agentType, _, err := newAgentType("s1-test-2")
		require.Nil(t, err)

		agent, token, err := newAgent(agentType)
		require.Nil(t, err)

		models.ForcefullyOccupyAgentWithJobID(agent)

		res := run("POST", "/refresh", token, nil)
		require.Equal(t, http.StatusOK, res.Code)

		response := &RefreshTokenResponse{}
		err = unmarshalJSON(res.Body, response)
		require.Nil(t, err)
		require.NotEmpty(t, response.Token)
	})
}

func Test__Occupancy(t *testing.T) {
	database.TruncateTables()

	t.Run("agent not found", func(t *testing.T) {
		token := "some-random-token-not-connected-to-an-agent"
		res := run("GET", "/occupancy", token, nil)
		require.Equal(t, http.StatusNotFound, res.Code)
	})

	t.Run("agent found and occupancy returned", func(t *testing.T) {
		_, token, err := newAgentType("s1-test")
		require.Nil(t, err)

		res := run("GET", "/occupancy", token, nil)
		require.Equal(t, http.StatusOK, res.Code)

		occupancyResponse := &JobOccupancy{}
		err = unmarshalJSON(res.Body, occupancyResponse)
		require.Nil(t, err)

		require.Equal(t, occupancyResponse.Queued, int32(3))
		require.Equal(t, occupancyResponse.Running, int32(1))
	})
}

func Test__Metrics(t *testing.T) {
	database.TruncateTables()

	t.Run("agent not found", func(t *testing.T) {
		token := "some-random-token-not-connected-to-an-agent"
		res := run("GET", "/metrics", token, nil)
		require.Equal(t, http.StatusNotFound, res.Code)
	})

	t.Run("agent found and metrics returned", func(t *testing.T) {
		agentType, token, err := newAgentType("s1-test")
		require.Nil(t, err)

		// 5 agents registered
		agents := []*models.Agent{}
		for i := 0; i < 5; i++ {
			agent, _, _ := newAgent(agentType)
			agents = append(agents, agent)
		}

		// 1 agent occupied
		models.ForcefullyOccupyAgentWithJobID(agents[0])

		res := run("GET", "/metrics", token, nil)
		require.Equal(t, http.StatusOK, res.Code)

		occupancyResponse := &AgentTypeMetrics{}
		err = unmarshalJSON(res.Body, occupancyResponse)
		require.Nil(t, err)
		require.Equal(t, occupancyResponse.Jobs.Queued, int32(3))
		require.Equal(t, occupancyResponse.Jobs.Running, int32(1))
		require.Equal(t, occupancyResponse.Agents.Idle, int32(4))
		require.Equal(t, occupancyResponse.Agents.Occupied, int32(1))
	})
}

//
// test utils
//

type syncAssertion struct {
	state           string
	token           string
	action          string
	jobIdOnRequest  string
	jobIdOnResponse string
	shutdownReason  string
	jobResult       string
	interruptedAt   int64
}

func sync(t *testing.T, assertion syncAssertion) {
	req := &agentsync.Request{
		State:         agentsync.AgentState(assertion.state),
		JobID:         assertion.jobIdOnRequest,
		JobResult:     agentsync.JobResult(assertion.jobResult),
		InterruptedAt: assertion.interruptedAt,
	}

	res := run("POST", "/sync", assertion.token, req)
	require.Equal(t, http.StatusOK, res.Code)

	var response agentsync.Response
	err := json.NewDecoder(res.Body).Decode(&response)
	require.Nil(t, err)
	require.Equal(t, response.Action, agentsync.AgentAction(assertion.action))
	require.Equal(t, response.JobID, assertion.jobIdOnResponse)

	if assertion.action == agentsync.AgentActionContinue && assertion.state == agentsync.AgentStateRunningJob {
		require.GreaterOrEqual(t, response.NextSyncAfter, 8000)
		require.LessOrEqual(t, response.NextSyncAfter, 12000)
	} else {
		require.GreaterOrEqual(t, response.NextSyncAfter, 4000)
		require.LessOrEqual(t, response.NextSyncAfter, 6000)
	}
}

func newAgentType(name string) (*models.AgentType, string, error) {
	return models.CreateAgentType(testOrgID, &testRequesterID, name)
}

func newAgentTypeWithSettings(name string, settings models.AgentNameSettings) (*models.AgentType, string, error) {
	return models.CreateAgentTypeWithSettings(testOrgID, &testRequesterID, name, settings)
}

func newAgent(agentType *models.AgentType) (*models.Agent, string, error) {
	randomName := fmt.Sprintf("%s-%d", agentType.Name, rand.Intn(100000000))
	return models.RegisterAgent(agentType.OrganizationID, agentType.Name, randomName, models.AgentMetadata{})
}

func newAgentWithMetadata(agentType *models.AgentType, metadata models.AgentMetadata) (*models.Agent, string, error) {
	randomName := fmt.Sprintf("%s-%d", agentType.Name, rand.Intn(100000000))
	return models.RegisterAgent(agentType.OrganizationID, agentType.Name, randomName, metadata)
}

func run(method, path, token string, body interface{}) *httptest.ResponseRecorder {
	stringBody := ""

	if body != nil {
		jsonBody, err := json.Marshal(body)
		if err != nil {
			panic(err)
		}

		stringBody = string(jsonBody)
	} else {
		stringBody = ""
	}

	bodyReader := strings.NewReader(stringBody)

	req, _ := http.NewRequest(method, "/api/v1/self_hosted_agents"+path, bodyReader)
	req.Header.Add("Authorization", "Token "+token)
	req.Header.Add("x-semaphore-org-id", testOrgID.String())
	req.Header.Add("x-forwarded-for", "1.1.1.1")
	req.Header.Add("user-agent", "Agent/v1.2.3")

	rr := httptest.NewRecorder()

	testServer.Router.ServeHTTP(rr, req)

	return rr
}

func unmarshalJSON(body io.Reader, t interface{}) error {
	return json.NewDecoder(body).Decode(t)
}

func declareExchangeAndQueue() error {
	connection, err := openConnection()
	if err != nil {
		return err
	}

	defer connection.Close()

	channel, err := connection.Channel()
	if err != nil {
		return err
	}

	defer channel.Close()

	err = channel.ExchangeDeclare("job_callbacks", "direct", true, false, false, false, nil)
	if err != nil {
		return err
	}

	err = channel.ExchangeDeclare("server_farm.job_state_exchange", "direct", true, false, false, false, nil)
	if err != nil {
		return err
	}

	err = channel.ExchangeDeclare("audit", "direct", true, false, false, false, nil)
	if err != nil {
		return err
	}

	_, err = channel.QueueDeclare("test_queue.finished", true, false, false, false, nil)
	if err != nil {
		return err
	}

	err = channel.QueueBind("test_queue.finished", "finished", "job_callbacks", false, nil)
	if err != nil {
		return err
	}

	_, err = channel.QueueDeclare("test_queue.job_teardown_finished", true, false, false, false, nil)
	if err != nil {
		return err
	}

	err = channel.QueueBind("test_queue.job_teardown_finished", "job_teardown_finished", "server_farm.job_state_exchange", false, nil)
	if err != nil {
		return err
	}

	_, err = channel.QueueDeclare("audit.log", true, false, false, false, nil)
	if err != nil {
		return err
	}

	err = channel.QueueBind("audit.log", "log", "audit", false, nil)
	if err != nil {
		return err
	}

	return nil
}

func purgeExchangeAndQueue() error {
	connection, err := openConnection()
	if err != nil {
		return err
	}

	defer connection.Close()

	channel, err := connection.Channel()
	if err != nil {
		return err
	}

	defer channel.Close()

	_, err = channel.QueueDelete("test_queue.finished", false, false, true)
	if err != nil {
		return err
	}

	_, err = channel.QueueDelete("test_queue.teardown_finished", false, false, true)
	if err != nil {
		return err
	}

	_, err = channel.QueueDelete("audit.log", false, false, true)
	if err != nil {
		return err
	}

	err = channel.ExchangeDelete("job_callbacks", false, true)
	if err != nil {
		return err
	}

	err = channel.ExchangeDelete("server_farm.job_state_exchange", false, true)
	if err != nil {
		return err
	}

	err = channel.ExchangeDelete("audit", false, true)
	if err != nil {
		return err
	}

	return nil
}

func checkFinishedEventReceived(t *testing.T, jobId, result string) {
	connection, err := openConnection()
	require.Nil(t, err)

	defer connection.Close()

	channel, err := connection.Channel()
	require.Nil(t, err)

	delivery, ok, err := channel.Get("test_queue.finished", true)
	require.Nil(t, err)
	require.True(t, ok)

	// assert job id
	message := map[string]interface{}{}
	err = json.Unmarshal(delivery.Body, &message)
	require.Nil(t, err)
	require.Equal(t, jobId, message["job_hash_id"])

	// asser payload
	payloadData := message["payload"].(string)
	payload := map[string]string{}
	err = json.Unmarshal([]byte(payloadData), &payload)
	require.Nil(t, err)
	require.Equal(t, jobId, message["job_hash_id"])

	require.Equal(t, result, payload["result"])
}

func checkNoFinishedEventReceived(t *testing.T) {
	connection, err := openConnection()
	require.Nil(t, err)

	defer connection.Close()

	channel, err := connection.Channel()
	require.Nil(t, err)

	_, ok, err := channel.Get("test_queue.finished", true)
	require.Nil(t, err)
	require.False(t, ok)
}

func checkTeardownFinishedEventReceived(t *testing.T, jobId string) {
	connection, err := openConnection()
	require.Nil(t, err)

	defer connection.Close()

	channel, err := connection.Channel()
	require.Nil(t, err)

	delivery, ok, err := channel.Get("test_queue.job_teardown_finished", true)
	require.Nil(t, err)
	require.True(t, ok)

	jobFinished := jobStateProtos.JobFinished{}
	err = proto.Unmarshal(delivery.Body, &jobFinished)
	require.Nil(t, err)
	require.True(t, jobFinished.SelfHosted)
	require.Equal(t, jobId, jobFinished.JobId)
	require.NotNil(t, jobFinished.GetTimestamp())
}

func checkNoTeardownFinishedEventReceived(t *testing.T) {
	connection, err := openConnection()
	require.Nil(t, err)

	defer connection.Close()

	channel, err := connection.Channel()
	require.Nil(t, err)

	_, ok, err := channel.Get("test_queue.job_teardown_finished", true)
	require.Nil(t, err)
	require.False(t, ok)
}

func checkAuditEventReceived(t *testing.T, agentName string, operation auditProtos.Event_Operation) {
	connection, err := openConnection()
	require.Nil(t, err)

	defer connection.Close()

	channel, err := connection.Channel()
	require.Nil(t, err)

	delivery, ok, err := channel.Get("audit.log", true)
	require.Nil(t, err)
	require.True(t, ok)

	event := auditProtos.Event{}
	err = proto.Unmarshal(delivery.Body, &event)
	require.Nil(t, err)
	require.NotNil(t, event.OperationId)
	require.NotNil(t, event.Description)
	require.NotNil(t, event.Timestamp)
	require.NotNil(t, event.Metadata)
	require.Equal(t, testRequesterID.String(), event.UserId)
	require.Equal(t, testOrgID.String(), event.OrgId)
	require.Equal(t, auditProtos.Event_SelfHostedAgent, event.Resource)
	require.Equal(t, agentName, event.ResourceName)
	require.Equal(t, operation, event.Operation)
	require.Equal(t, auditProtos.Event_API, event.Medium)
}

func checkNoAuditEventReceived(t *testing.T) {
	connection, err := openConnection()
	require.Nil(t, err)

	defer connection.Close()

	channel, err := connection.Channel()
	require.Nil(t, err)

	_, ok, err := channel.Get("audit.log", true)
	require.Nil(t, err)
	require.False(t, ok)
}

func registerRequest(name string) *RegisterRequest {
	return &RegisterRequest{
		Version:     "v2.0.12",
		Name:        name,
		OS:          "Ubuntu",
		Arch:        "x86_64",
		PID:         9999999,
		Hostname:    "ip-172-31-1-1",
		SingleJob:   true,
		IdleTimeout: 120,
	}
}

func parseResponse(t *testing.T, response *httptest.ResponseRecorder) *RegisterResponse {
	body, err := ioutil.ReadAll(response.Body)
	require.NoError(t, err)

	regResponse := RegisterResponse{}
	err = json.Unmarshal(body, &regResponse)
	require.NoError(t, err)

	return &regResponse
}

func openConnection() (*amqp091.Connection, error) {
	config := amqp091.Config{Properties: amqp091.NewConnectionProperties()}
	config.Properties.SetClientConnectionName("self_hosted_hub")

	return amqp091.DialConfig("amqp://guest:guest@rabbitmq:5672", config)
}
