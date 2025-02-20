package publicapi

import (
	"fmt"
	"io"
	"math/rand"
	"net/http"
	"os"
	"testing"

	"github.com/google/uuid"
	agentsync "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/agentsync"
	"github.com/semaphoreio/semaphore/self_hosted_hub/pkg/database"
	models "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/models"
	securetoken "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/securetoken"
	grpcmock "github.com/semaphoreio/semaphore/self_hosted_hub/test/grpcmock"
	require "github.com/stretchr/testify/require"
)

func Test__Register(t *testing.T) {
	database.TruncateTables()
	grpcmock.Start()

	t.Run("it responds with the a register response and creates record", func(t *testing.T) {
		_, token, _ := newAgentType("s1-test")
		res := run("POST", "/register", token, registerRequest("hello"))
		registerResponse := &RegisterResponse{}
		require.Equal(t, http.StatusCreated, res.Code)

		err := unmarshalJSON(res.Body, registerResponse)
		require.Nil(t, err)

		require.Equal(t, registerResponse.Name, "hello")
		require.NotEmpty(t, registerResponse.Token)

		agent, err := models.FindAgentByToken(testOrgID.String(), securetoken.Hash(registerResponse.Token))
		require.Nil(t, err)
		require.Equal(t, agent.Name, "hello")
		require.Equal(t, agent.OS, "Ubuntu")
		require.Equal(t, agent.Arch, "x86_64")
		require.Equal(t, agent.PID, 9999999)
		require.Equal(t, agent.Hostname, "ip-172-31-1-1")
		require.Equal(t, agent.IPAddress, "1.1.1.1")
		require.Equal(t, agent.UserAgent, "Agent/v1.2.3")
		require.Equal(t, agent.Version, "v2.0.12")
		require.Equal(t, agent.SingleJob, true)
		require.Equal(t, agent.IdleTimeout, 120)
		require.NoError(t, agent.Disconnect())
	})

	t.Run("it fails if the same name is used", func(t *testing.T) {
		_, token, _ := newAgentType(fmt.Sprintf("s1-test-%d", rand.Int()))
		res := run("POST", "/register", token, registerRequest("hello"))
		accessToken := parseResponse(t, res).Token
		require.Equal(t, http.StatusCreated, res.Code)
		sync(t, syncAssertion{
			state:  agentsync.AgentStateWaitingForJobs,
			token:  accessToken,
			action: agentsync.AgentActionContinue,
		})

		res = run("POST", "/register", token, registerRequest("hello"))
		require.Equal(t, http.StatusBadRequest, res.Code)

		run("POST", "/disconnect", accessToken, nil)
	})

	t.Run("same name can be used after agent disconnects", func(t *testing.T) {
		_, token, _ := newAgentType(fmt.Sprintf("s1-test-%d", rand.Int()))
		name := fmt.Sprintf("hello-%d", rand.Int())

		// agent registers and syncs
		res := run("POST", "/register", token, registerRequest(name))
		require.Equal(t, http.StatusCreated, res.Code)
		accessToken := parseResponse(t, res).Token
		sync(t, syncAssertion{
			state:  agentsync.AgentStateWaitingForJobs,
			token:  accessToken,
			action: agentsync.AgentActionContinue,
		})

		// another agent with same name tries to register again
		res = run("POST", "/register", token, registerRequest(name))
		require.Equal(t, http.StatusBadRequest, res.Code)

		// agent disconnects
		res = run("POST", "/disconnect", accessToken, nil)
		require.Equal(t, http.StatusOK, res.Code)

		// another agent with same name can register now
		res = run("POST", "/register", token, registerRequest(name))
		require.Equal(t, http.StatusCreated, res.Code)
		res = run("POST", "/disconnect", parseResponse(t, res).Token, nil)
		require.Equal(t, http.StatusOK, res.Code)
	})

	t.Run("it fails if feature is not enabled", func(t *testing.T) {
		os.Setenv("SELF_HOSTED_QUOTAS", "disabled")
		quotaClient.Clear(testOrgID.String())

		_, token, _ := newAgentType(fmt.Sprintf("s1-test-%d", rand.Int()))
		res := run("POST", "/register", token, registerRequest("hello6"))
		require.Equal(t, http.StatusUnprocessableEntity, res.Code)
		body, err := io.ReadAll(res.Body)
		require.NoError(t, err)
		require.Contains(t, string(body), "self_hosted_agents feature is not available for the organization")

		os.Setenv("SELF_HOSTED_QUOTAS", "")
		quotaClient.Clear(testOrgID.String())
	})

	t.Run("it fails if max number of agents has been reached", func(t *testing.T) {
		_, token, _ := newAgentType(fmt.Sprintf("s1-test-%d", rand.Int()))

		agents, _, err := models.ListAgentsWithCursor(testOrgID, "", 100, "")
		require.Nil(t, err)
		require.Len(t, agents, 0)

		// disconnect all agents after test is finished
		defer func() {
			agents, _, _ := models.ListAgentsWithCursor(testOrgID, "", 100, "")
			for _, agent := range agents {
				agent.Disconnect()
			}
		}()

		// we can register up to 5 agents
		res := run("POST", "/register", token, registerRequest(fmt.Sprintf("hello-%d", rand.Int())))
		require.Equal(t, http.StatusCreated, res.Code)
		res = run("POST", "/register", token, registerRequest(fmt.Sprintf("hello-%d", rand.Int())))
		require.Equal(t, http.StatusCreated, res.Code)
		res = run("POST", "/register", token, registerRequest(fmt.Sprintf("hello-%d", rand.Int())))
		require.Equal(t, http.StatusCreated, res.Code)
		res = run("POST", "/register", token, registerRequest(fmt.Sprintf("hello-%d", rand.Int())))
		require.Equal(t, http.StatusCreated, res.Code)
		res = run("POST", "/register", token, registerRequest(fmt.Sprintf("hello-%d", rand.Int())))
		require.Equal(t, http.StatusCreated, res.Code)

		// on the 6th agent, we are blocked
		res = run("POST", "/register", token, registerRequest(fmt.Sprintf("hello-%d", rand.Int())))
		require.Equal(t, http.StatusUnprocessableEntity, res.Code)
		body, err := io.ReadAll(res.Body)
		require.NoError(t, err)
		require.Contains(t, string(body), "agent quota for organization has been reached")

		// even if we use a different agent type
		_, token, _ = newAgentType("s1-test-2")
		res = run("POST", "/register", token, registerRequest(fmt.Sprintf("hello-%d", rand.Int())))
		require.Equal(t, http.StatusUnprocessableEntity, res.Code)
		body, err = io.ReadAll(res.Body)
		require.NoError(t, err)
		require.Contains(t, string(body), "agent quota for organization has been reached")
	})

	t.Run("it fails if agent type requests plain name and URL is used", func(t *testing.T) {
		_, token, _ := newAgentType(fmt.Sprintf("s1-test-%d", rand.Int()))

		// Fails when AWS STS URL is used
		res := run("POST", "/register", token, registerRequest("https://sts.amazonaws.com/aoisaosifhoisfh"))
		require.Equal(t, http.StatusBadRequest, res.Code)
		body, err := io.ReadAll(res.Body)
		require.NoError(t, err)
		require.Contains(t, string(body), "not allowed to use URLs for registration")

		// Fails when any URL is used
		res = run("POST", "/register", token, registerRequest("https://example.com/aoisaosifhoisfh"))
		require.Equal(t, http.StatusBadRequest, res.Code)
		body, err = io.ReadAll(res.Body)
		require.NoError(t, err)
		require.Contains(t, string(body), "not allowed to use URLs for registration")
	})

	t.Run("it fails if agent type requests AWS STS URL instead of plain name", func(t *testing.T) {
		_, token, _ := newAgentTypeWithSettings("s1-aws", models.AgentNameSettings{
			NameAssignmentOrigin: models.NameAssignmentOriginFromAWSSTS,
			AWSAccount:           "1234",
			AWSRoleNamePatterns:  "role-1",
		})

		res := run("POST", "/register", token, registerRequest("hello2"))
		require.Equal(t, http.StatusBadRequest, res.Code)
		body, err := io.ReadAll(res.Body)
		require.NoError(t, err)
		require.Contains(t, string(body), "only pre-signed AWS STS URLs for name assignment are allowed")
	})

	t.Run("it fails if job is requested and occupation request does not exist", func(t *testing.T) {
		agentTypeName := fmt.Sprintf("s1-test-%d", rand.Int())
		_, token, _ := newAgentType(agentTypeName)

		agentName := fmt.Sprintf("%s-%d", agentTypeName, rand.Intn(100000000))
		req := registerRequest(agentName)
		req.JobID = uuid.New().String()

		res := run("POST", "/register", token, req)
		require.Equal(t, http.StatusBadRequest, res.Code)
		errMessage, _ := io.ReadAll(res.Body)
		require.Contains(t, string(errMessage), ErrOccupationRequestNotFound.Error())
	})

	t.Run("it fails if job is requested but agent is not in single-job mode", func(t *testing.T) {
		agentTypeName := fmt.Sprintf("s1-test-%d", rand.Int())
		_, token, _ := newAgentType(agentTypeName)

		agentName := fmt.Sprintf("%s-%d", agentTypeName, rand.Intn(100000000))
		req := registerRequest(agentName)
		req.JobID = uuid.New().String()
		req.SingleJob = false

		res := run("POST", "/register", token, req)
		require.Equal(t, http.StatusBadRequest, res.Code)
		errMessage, _ := io.ReadAll(res.Body)
		require.Contains(t, string(errMessage), "job can only be requested if agent disconnects after running it")
	})

	t.Run("it succeeds if job is requested and is available", func(t *testing.T) {
		agentTypeName := fmt.Sprintf("s1-test-%d", rand.Int())
		agentType, token, _ := newAgentType(agentTypeName)
		jobID := uuid.New()
		require.NoError(t, models.CreateOccupationRequest(testOrgID, agentTypeName, jobID))

		agentName := fmt.Sprintf("%s-%d", agentType.Name, rand.Intn(100000000))
		req := registerRequest(agentName)
		req.JobID = jobID.String()

		res := run("POST", "/register", token, req)
		require.Equal(t, http.StatusCreated, res.Code)

		agent, err := models.FindAgentByName(testOrgID.String(), agentName)
		require.NoError(t, err)
		require.Equal(t, jobID, *agent.AssignedJobID)
	})
}
