package agentsync

import (
	"context"
	"errors"
	"fmt"
	"math/rand"
	"os"
	"strconv"
	"time"

	"github.com/google/uuid"
	"github.com/semaphoreio/semaphore/self_hosted_hub/pkg/amqp"
	logging "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/logging"
	models "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/models"
	quotas "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/quotas"
	"github.com/semaphoreio/semaphore/self_hosted_hub/pkg/workers/agentcounter"
	log "github.com/sirupsen/logrus"
	"gorm.io/gorm"
)

type AgentState string
type AgentAction string
type JobResult string
type ShutdownReason string

const AgentStateWaitingForJobs = "waiting-for-jobs"
const AgentStateStartingJob = "starting-job"
const AgentStateRunningJob = "running-job"
const AgentStateStoppingJob = "stopping-job"
const AgentStateFinishedJob = "finished-job"

/*
 * These states are not used by agent using newer versions anymore.
 * These states were required when the job callback broker was being used.
 * However, people might still be using old agents, so SHH needs to know how to handle these state as well.
 * Once we are sure no old agents are being used, we can remove these.
 */
const AgentStateFailedToFetchJob = "failed-to-fetch-job"
const AgentStateFailedToConstructJob = "failed-to-construct-job"
const AgentStateFailedToSendCallback = "failed-to-send-callback"

const AgentActionWaitForJobs = "wait-for-jobs"
const AgentActionRunJob = "run-job"
const AgentActionStopJob = "stop-job"
const AgentActionShutdown = "shutdown"
const AgentActionContinue = "continue"

const JobResultFailed = "failed"
const JobResultPassed = "passed"
const JobResultStopped = "stopped"

const ShutdownReasonIdle = "idle"
const ShutdownReasonRequested = "requested"
const ShutdownReasonInterrupted = "interrupted"
const ShutdownReasonJobFinished = "job-finished"

// By default, agents will use a sync interval between 4 and 6s.
const defaultIntervalFloorMillis = 4000
const defaultIntervalCeilMillis = 6000

type Request struct {
	State         AgentState `json:"state"`
	JobID         string     `json:"job_id"`
	JobResult     JobResult  `json:"job_result"`
	InterruptedAt int64      `json:"interrupted_at"`
}

type Response struct {
	Action         AgentAction    `json:"action"`
	JobID          string         `json:"job_id"`
	ShutdownReason ShutdownReason `json:"shutdown_reason"`
	NextSyncAfter  int            `json:"next_sync_after"`
}

func Process(ctx context.Context, quotaClient *quotas.QuotaClient, agentCounter *agentcounter.AgentCounter, publisher *amqp.Publisher, agent *models.Agent, request *Request) (*Response, error) {
	var err error

	// If the self_hosted_agents feature was disabled for the organization,
	// or the organization quota decreased and there's more agents connected
	// than the new quota allows, we disable the agent before responding,
	// which will properly disconnect that agent.
	if !hasEnoughQuota(ctx, quotaClient, agentCounter, agent) {
		logging.ForAgent(agent).Info("Disabling agent")
		agent, err = models.DisableAgent(agent.OrganizationID, agent.AgentTypeName, agent.Name)
		if err != nil {
			logging.ForAgent(agent).Errorf("Error disabling agent: %v", err)
		}

		// If we get into a state where the quota was decreased,
		// and we are disabling agents to fit the new quota,
		// we refresh the agent counter on every agent we disable,
		// to ensure we have the latest agent count for subsequent requests.
		agentCounter.Refresh()
	}

	return answer(ctx, publisher, agent, request)
}

func hasEnoughQuota(ctx context.Context, quotaClient *quotas.QuotaClient, agentCounter *agentcounter.AgentCounter, agent *models.Agent) bool {
	quota, err := quotaClient.GetQuotaWithContext(ctx, agent.OrganizationID.String())

	// Here, we fail open, because we don't want to block
	// valid agents that already registered due to errors on our side.
	if err != nil {
		logging.ForAgent(agent).Errorf("Error getting organization quota: %v", err)
		return true
	}

	// The feature was disabled.
	if !quota.Enabled {
		logging.ForAgent(agent).Infof("Feature was disabled")
		return false
	}

	// The feature could still be enabled, but the quota could have decreased.
	// We should disable the agent if the current number of agents is above the new quota.
	currentCount := agentCounter.Get(agent.OrganizationID.String())
	if currentCount > int(quota.Quantity) {
		logging.ForAgent(agent).Infof("Current number of agents (%d) is above quota (%d)", currentCount, quota.Quantity)
		return false
	}

	// If we get here, we know everything is fine with the quota,
	// so the agent should not be disabled.
	return true
}

func answer(ctx context.Context, publisher *amqp.Publisher, agent *models.Agent, req *Request) (*Response, error) {
	switch req.State {
	case AgentStateWaitingForJobs:
		return handleWaitingForJobsState(ctx, publisher, agent, req)

	case AgentStateRunningJob:
		return handleRunningJobState(agent, req)

	case AgentStateStoppingJob, AgentStateStartingJob:
		return actionContinue(req), nil

	case AgentStateFinishedJob:
		return handleFinishedJobState(ctx, publisher, agent, req.JobID, req.JobResult)

	// We still need to handle these because of old agents.
	// However, once we are sure agents being registered are no longer sending these, we can remove it.
	// We treat this as a job-finished state, because new agents send these errors in a job-finished state sync.
	case AgentStateFailedToFetchJob, AgentStateFailedToConstructJob, AgentStateFailedToSendCallback:
		return handleFinishedJobState(ctx, publisher, agent, agent.AssignedJobID.String(), JobResultFailed)
	}

	panic("invalid state - this should never happen")
}

func handleWaitingForJobsState(ctx context.Context, publisher *amqp.Publisher, agent *models.Agent, req *Request) (*Response, error) {

	// If the agent has been disconnected from the UI, tell it to shut down.
	if agent.DisabledAt != nil {
		return actionShutdown(ShutdownReasonRequested), nil
	}

	// If the agent has been interrupted (SIGTERM), tell it to shut down.
	if agent.InterruptedAt != nil {
		return actionShutdown(ShutdownReasonInterrupted), nil
	}

	// If the agent was assigned a job during registration,
	// we don't need to look for an occupation request again.
	if agent.AssignedJobID != nil && agent.AssignedJobID.String() != agent.LastSyncJobID {
		jobID := agent.AssignedJobID.String()
		if err := publisher.PublishStartedCallback(ctx, jobID, agent); err != nil {
			log.Errorf("Error publishing started message for %s: %v", jobID, err)
		}

		return actionRunJob(agent.AssignedJobID.String()), nil
	}

	// If the agent hasn't been assigned to a job yet,
	// but an occupation request exists, tell it to run it.
	if jobID, err := models.OccupyAgent(agent); err == nil {
		if err := publisher.PublishStartedCallback(ctx, jobID, agent); err != nil {
			log.Errorf("Error publishing started message for %s: %v", jobID, err)
		}

		return actionRunJob(jobID), nil
	}

	// If the agent is not configured to shut down due to idleness,
	// it should continue waiting for more jobs.
	if agent.IdleTimeout == 0 {
		return actionContinue(req), nil
	}

	// If the agent is configured to shut down due to idleness,
	// we check if that timeout has passed. Note that the check
	// for idleness happens after the check for a new job assignment.
	idleFor := int(time.Since(*agent.LastStateChangeAt) / time.Second)
	if idleFor < agent.IdleTimeout {
		return actionContinue(req), nil
	}

	// If there's no error disabling the agent, the agent can safely shut down.
	return actionShutdown(ShutdownReasonIdle), nil
}

func handleRunningJobState(agent *models.Agent, req *Request) (*Response, error) {
	// If the job the agent is running was stopped, tell it to stop it.
	if agent.JobStopRequestedAt != nil {
		return actionStopJob(agent.AssignedJobID.String()), nil
	}

	// If the agent was disabled in the UI, tell it to stop the job it is running first.
	if agent.DisabledAt != nil {
		return actionStopJob(agent.AssignedJobID.String()), nil
	}

	// If the agent process was interrupted (receives a SIGTERM signal),
	// we check if it has reached the grace period. If it has, we tell it to stop the job.
	if agent.InterruptedAt != nil {
		interruptedFor := int(time.Since(*agent.InterruptedAt) / time.Second)
		if interruptedFor >= agent.InterruptionGracePeriod {
			return actionStopJob(agent.AssignedJobID.String()), nil
		}
	}

	return actionContinue(req), nil
}

func handleFinishedJobState(ctx context.Context, publisher *amqp.Publisher, agent *models.Agent, jobID string, result JobResult) (*Response, error) {
	jobUUID, err := uuid.Parse(jobID)
	if err != nil {
		return nil, err
	}

	/*
	 * We only release agents that will be assigned to more jobs, and that haven't been interrupted.
	 * The other agents will be told to shut down, so we don't need to release them.
	 */
	if !agent.SingleJob && agent.InterruptedAt == nil {

		_, err = models.ReleaseAgent(agent.OrganizationID, agent.AgentTypeName, jobUUID)
		if err != nil {

			/*
			 * If the agent has already been released, it means the agent used callbacks (old agent).
			 * To account for that, we make sure we don't error out if the agent has already been released.
			 */
			if errors.Is(err, gorm.ErrRecordNotFound) {
				logging.ForAgent(agent).Warningf("Agent was not assigned to %s - ignoring", jobID)
			} else {
				logging.ForAgent(agent).Errorf("Error releasing agent after %s finished: %v", jobID, err)
				return nil, err
			}
		}
	}

	/*
	 * If the result received in the job-finished sync request is empty,
	 * it means the agent was using callbacks, so we don't send them again here.
	 */
	if result != "" {
		err = publisher.HandleJobFinished(ctx, jobID, string(result))
		if err != nil {
			return nil, err
		}
	}

	// If agent was disconnected from the UI, we tell it to shut down.
	if agent.DisabledAt != nil {
		return actionShutdown(ShutdownReasonRequested), nil
	}

	// If agent is supposed to run only a single job, we tell it to shut down.
	if agent.SingleJob {
		return actionShutdown(ShutdownReasonJobFinished), nil
	}

	// If agent was interrupted, we tell it to shutdown.
	if agent.InterruptedAt != nil {
		return actionShutdown(ShutdownReasonInterrupted), nil
	}

	// If none of the conditions above are met, the agent should wait for more jobs.
	return actionWaitForJobs(), nil
}

func actionRunJob(jobID string) *Response {
	return &Response{
		Action:        AgentActionRunJob,
		JobID:         jobID,
		NextSyncAfter: defaultInterval(),
	}
}

func actionStopJob(jobID string) *Response {
	return &Response{
		Action:        AgentActionStopJob,
		JobID:         jobID,
		NextSyncAfter: defaultInterval(),
	}
}

func actionContinue(req *Request) *Response {
	// If we are telling the agent to continue, and it is running a job,
	// we use a bigger interval. The reason for this is that the only
	// things that could change this state (from the API perspective) is the job being stopped.
	// That does not happen often, and when it does, it is OK if they take a little bit longer.
	if req.State == AgentStateRunningJob {
		return &Response{
			Action:        AgentActionContinue,
			NextSyncAfter: defaultInterval() * 2,
		}
	}

	// Otherwise, we just use an interval in the default range.
	return &Response{
		Action:        AgentActionContinue,
		NextSyncAfter: defaultInterval(),
	}
}

func actionShutdown(reason ShutdownReason) *Response {
	return &Response{
		Action:         AgentActionShutdown,
		ShutdownReason: reason,
		NextSyncAfter:  defaultInterval(),
	}
}

func actionWaitForJobs() *Response {
	return &Response{
		Action:        AgentActionWaitForJobs,
		NextSyncAfter: defaultInterval(),
	}
}

func millisInRange(minMillis, maxMillis int) (int, error) {
	if minMillis <= 0 {
		return 0, fmt.Errorf("min cannot be less than or equal to zero")
	}

	if minMillis >= maxMillis {
		return 0, fmt.Errorf("max cannot be greater than or equal to zero")
	}

	// #nosec
	interval := rand.Intn(maxMillis-minMillis) + minMillis
	return interval, nil
}

func defaultInterval() int {
	floor := valueFromEnv(os.Getenv("SYNC_INTERVAL_FLOOR"), defaultIntervalFloorMillis)
	ceil := valueFromEnv(os.Getenv("SYNC_INTERVAL_CEIL"), defaultIntervalCeilMillis)
	millis, err := millisInRange(floor, ceil)
	if err != nil {
		ms, _ := millisInRange(defaultIntervalFloorMillis, defaultIntervalCeilMillis)
		return ms
	}

	return millis
}

func valueFromEnv(valueFromEnv string, valueDefault int) int {
	if valueFromEnv == "" {
		return valueDefault
	}

	value, err := strconv.Atoi(valueFromEnv)
	if err != nil {
		return valueDefault
	}

	return value
}
