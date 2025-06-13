package publicapi

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/url"
	"os"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/gorilla/handlers"
	"github.com/gorilla/mux"
	watchman "github.com/renderedtext/go-watchman"
	agentsync "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/agentsync"
	amqp "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/amqp"
	"github.com/semaphoreio/semaphore/self_hosted_hub/pkg/aws"
	"github.com/semaphoreio/semaphore/self_hosted_hub/pkg/database"
	logging "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/logging"
	models "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/models"
	"github.com/semaphoreio/semaphore/self_hosted_hub/pkg/protos/audit"
	zebra "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/protos/server_farm.job"
	loghub2 "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/publicapi/loghub2"
	zebraclient "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/publicapi/zebraclient"
	quotas "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/quotas"
	"github.com/semaphoreio/semaphore/self_hosted_hub/pkg/workers/agentcounter"
	log "github.com/sirupsen/logrus"
	"gorm.io/gorm"
)

var ErrUnknownQuota = errors.New("unknown agent quota for organization")
var ErrQuotaReached = errors.New("agent quota for organization has been reached")
var ErrFeatureNotAvailable = errors.New("self_hosted_agents feature is not available for the organization")
var ErrOccupationRequestNotFound = errors.New("job not available")

type Server struct {
	httpServer            *http.Server
	timeoutHandlerTimeout time.Duration
	Router                *mux.Router
	quotaClient           *quotas.QuotaClient
	agentCounter          *agentcounter.AgentCounter
	publisher             *amqp.Publisher
	httpClient            *http.Client
}

func NewServer(
	quotaClient *quotas.QuotaClient,
	agentCounter *agentcounter.AgentCounter,
	publisher *amqp.Publisher,
	additionalMiddlewares ...mux.MiddlewareFunc) (*Server, error) {
	go agentCounter.Start()

	httpClient := http.Client{
		Timeout: 5 * time.Second,
	}

	server := &Server{
		quotaClient:  quotaClient,
		publisher:    publisher,
		agentCounter: agentCounter,
		httpClient:   &httpClient,
	}

	server.timeoutHandlerTimeout = 15 * time.Second
	server.InitRouter(additionalMiddlewares...)
	return server, nil
}

func (s *Server) SetTimeoutHandlerTimeout(t time.Duration) {
	s.timeoutHandlerTimeout = t
}

func (s *Server) InitRouter(additionalMiddlewares ...mux.MiddlewareFunc) {
	r := mux.NewRouter().StrictSlash(true)

	basePath := "/api/v1/self_hosted_agents"

	authenticatedRoute := r.Methods(http.MethodPost, http.MethodGet).Subrouter()
	// these endpoints are authenticated using the agent type token
	authenticatedRoute.HandleFunc(basePath+"/register", s.Register).Methods("POST")
	authenticatedRoute.HandleFunc(basePath+"/metrics", s.GetMetrics).Methods("GET")
	// /occupancy is a deprecated endpoint and should be removed once no one is using it
	authenticatedRoute.HandleFunc(basePath+"/occupancy", s.GetOccupancy).Methods("GET")

	// these endpoints are authenticated using the agent token
	authenticatedRoute.HandleFunc(basePath+"/sync", s.Sync).Methods("POST")
	authenticatedRoute.HandleFunc(basePath+"/disconnect", s.Disconnect).Methods("POST")
	authenticatedRoute.HandleFunc(basePath+"/refresh", s.RefreshToken).Methods("POST")
	authenticatedRoute.HandleFunc(basePath+"/jobs/{job_id}", s.DescribeJob).Methods("GET")
	authenticatedRoute.HandleFunc(basePath+"/jobs", s.ListJobs).Methods("GET")
	authenticatedRoute.Use(authMiddleware, handlers.ProxyHeaders)
	authenticatedRoute.Use(additionalMiddlewares...)

	unauthenticatedRoute := r.Methods(http.MethodGet).Subrouter()
	unauthenticatedRoute.HandleFunc("/", s.HealthCheck).Methods("GET")

	s.Router = r
}

func (s *Server) HealthCheck(w http.ResponseWriter, r *http.Request) {
	respondWith200(w)
}

type RefreshTokenResponse struct {
	Token string `json:"token"`
}

func (s *Server) RefreshToken(w http.ResponseWriter, r *http.Request) {
	defer watchman.Benchmark(time.Now(), "token.refresh")

	agent, err := findAgent(r)
	if err != nil {
		respondWith404(w)
		return
	}

	logging.ForAgent(agent).Infof("Refresh token requested")

	// agent is not assigned any jobs,
	// so it should not be refreshing any tokens.
	if agent.AssignedJobID == nil {
		logging.ForAgent(agent).Warning("Agent is not assigned any jobs")
		respondWith422(w)
		return
	}

	newToken, err := loghub2.GenerateToken(agent.AssignedJobID.String())
	if err != nil {
		logging.ForAgent(agent).Errorf("Error generating new token: %v", err)
		_ = watchman.IncrementWithTags("server.error", []string{"refresh_token", agent.OrganizationID.String()})
		respondWith500(w)
		return
	}

	logging.ForAgent(agent).Infof("Successfully generated new token")
	err = respondWithJSON(w, http.StatusOK, &RefreshTokenResponse{
		Token: newToken,
	})

	if err != nil {
		respondWith500(w)
	}
}

func (s *Server) DescribeJob(w http.ResponseWriter, r *http.Request) {
	defer watchman.Benchmark(time.Now(), "job.describe")

	agent, err := findAgent(r)
	if err != nil {
		respondWith404(w)
		return
	}

	jobID := mux.Vars(r)["job_id"]
	logging.ForAgent(agent).Infof("Get job %s", jobID)
	if !agent.IsRunningJob(jobID) {
		logging.ForAgent(agent).Warningf("Agent is not running job %s", jobID)
		respondWith404(w)
		return
	}

	payload, err := zebraclient.GetJobPayload(jobID)
	if err != nil {
		logging.ForAgent(agent).Errorf("Error fetching job payload for %s: %v", jobID, err)
		_ = watchman.IncrementWithTags("server.error", []string{"zebra_failure", agent.OrganizationID.String()})
		respondWith500(w)
		return
	}

	err = respondWithString(w, http.StatusOK, payload)
	if err != nil {
		respondWith500(w)
	}
}

type RegisterRequest struct {
	Version                 string `json:"version"`
	Arch                    string `json:"arch"`
	Name                    string `json:"name"`
	OS                      string `json:"os"`
	PID                     int    `json:"pid"`
	Hostname                string `json:"hostname"`
	SingleJob               bool   `json:"single_job"`
	IdleTimeout             int    `json:"idle_timeout"`
	InterruptionGracePeriod int    `json:"interruption_grace_period"`
	JobID                   string `json:"job_id"`
}

type RegisterResponse struct {
	Name  string `json:"name"`
	Token string `json:"token"`
}

func (s *Server) Register(w http.ResponseWriter, r *http.Request) {
	defer watchman.Benchmark(time.Now(), "agent.register")

	agentType, err := findAgentType(r)
	if err != nil {
		respondWith404(w)
		return
	}

	var info RegisterRequest
	err = json.NewDecoder(r.Body).Decode(&info)
	if err != nil {
		respondWith422(w)
		return
	}

	if info.JobID != "" && !info.SingleJob {
		http.Error(w, "job can only be requested if agent disconnects after running it", http.StatusBadRequest)
		return
	}

	agentName, err := s.assignAgentName(r.Context(), agentType, info.Name)
	if err != nil {
		logging.ForAgentType(agentType).Errorf("Error assigning agent name: %v", err)
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	metadata := models.AgentMetadata{
		Version:                 info.Version,
		OS:                      info.OS,
		Arch:                    info.Arch,
		PID:                     info.PID,
		Hostname:                info.Hostname,
		UserAgent:               r.Header.Get("user-agent"),
		SingleJob:               info.SingleJob,
		IdleTimeout:             info.IdleTimeout,
		InterruptionGracePeriod: info.InterruptionGracePeriod,
		IPAddress:               r.RemoteAddr, // populated by handlers.ProxyHeaders middleware
	}

	// We use a blocking advisory lock here because counting the current number of agents
	// and inserting a new one is not an atomic operation.
	// If we don't use a lock, and multiple agents register around
	// the same time, we can end up allowing the organization to go beyond its quota.
	// The blocking advisory lock makes it atomic, and guarantees that this issue doesn't happen.
	// We use the request's context to cancel the operation if the lock isn't grabbed on time.
	var agent *models.Agent
	var agentToken string
	err = database.WithBlockingAdvisoryLock(r.Context(), agentType.OrganizationID.String(), func(tx *gorm.DB) error {
		a, t, err := s.registerAgent(r.Context(), tx, agentType, agentName, info.JobID, metadata)
		if err != nil {
			return err
		}

		agent = a
		agentToken = t
		return nil
	})

	// If everything was successful, we publish an audit log
	// and write the response back to the agent.
	if err == nil {
		_ = s.publisher.PublishAuditLogEvent(r.Context(), agent, amqp.AuditLogOptions{
			UserID:      agentType.RequesterID,
			Operation:   audit.Event_Added,
			Description: "Self-hosted agent registered",
		})

		logging.ForAgent(agent).Infof("Registered agent: %v", metadata)
		err = respondWithJSON(w, http.StatusCreated, &RegisterResponse{
			Name:  agent.Name,
			Token: agentToken,
		})

		if err != nil {
			respondWith500(w)
		}

		return
	}

	if errors.Is(err, ErrQuotaReached) || errors.Is(err, ErrFeatureNotAvailable) {
		http.Error(w, err.Error(), http.StatusUnprocessableEntity)
		return
	}

	if errors.Is(err, models.ErrAgentCantBeRegistered) || errors.Is(err, ErrOccupationRequestNotFound) {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	// If we get here, some unknown error happened
	log.Errorf("Error registering agent for organization %s: %v", agentType.OrganizationID.String(), err)
	http.Error(w, err.Error(), http.StatusInternalServerError)
}

func (s *Server) parseJobID(job string) (*uuid.UUID, error) {
	if job == "" {
		return nil, nil
	}

	jobID, err := uuid.Parse(job)
	if err != nil {
		return nil, err
	}

	return &jobID, nil
}

func (s *Server) registerAgent(ctx context.Context, tx *gorm.DB, agentType *models.AgentType, agentName, job string, metadata models.AgentMetadata) (*models.Agent, string, error) {
	err := s.checkQuotaForNewAgent(ctx, tx, agentType.OrganizationID.String())
	if err != nil {
		return nil, "", err
	}

	// No job is requested on registration.
	if job == "" {
		return models.RegisterAgentInTransaction(
			tx,
			agentType.OrganizationID,
			agentType.Name,
			agentName,
			nil,
			metadata,
		)
	}

	jobID, err := s.parseJobID(job)
	if err != nil {
		return nil, "", err
	}

	if _, err := models.FindOccupationRequestInTransaction(tx, agentType.OrganizationID, agentType.Name, *jobID); err != nil {
		return nil, "", ErrOccupationRequestNotFound
	}

	return models.RegisterAgentInTransaction(
		tx,
		agentType.OrganizationID,
		agentType.Name,
		agentName,
		jobID,
		metadata,
	)
}

func (s *Server) checkQuotaForNewAgent(ctx context.Context, tx *gorm.DB, orgID string) error {
	orgQuota, err := s.quotaClient.GetQuotaWithContext(ctx, orgID)

	// if we can't get the quotas, we don't let any agents register.
	if err != nil {
		log.Errorf("Error finding agent quota for organization %s: %v", orgID, err)
		return fmt.Errorf("unknown agent quota for organization %s", orgID)
	}

	// self-hosted feature is not enabled for organization
	if !orgQuota.Enabled {
		log.Infof("Self-hosted is not available for %s - rejecting", orgID)
		return ErrFeatureNotAvailable
	}

	currentCount, err := models.CountAgentsInOrganizationInTransaction(ctx, tx, orgID)
	if err != nil {
		log.Errorf("Error finding current agent count for organization %s: %v", orgID, err)
		return fmt.Errorf("unknown agent count for organization")
	}

	// self-hosted feature is enabled,
	// but the current number of agents is above the organization quota.
	if currentCount >= int(orgQuota.Quantity) {
		log.Infof("Number of current agents (%d) is above quota (%d) for %s - rejecting", currentCount, orgQuota.Quantity, orgID)
		return ErrQuotaReached
	}

	// self-hosted feature is enabled and the organization has enough quota.
	return nil
}

type AgentTypeMetrics struct {
	Jobs   JobOccupancy   `json:"jobs"`
	Agents AgentOccupancy `json:"agents"`
}

type JobOccupancy struct {
	Queued  int32 `json:"queued"`
	Running int32 `json:"running"`
}

type AgentOccupancy struct {
	Idle     int32 `json:"idle"`
	Occupied int32 `json:"occupied"`
}

func (s *Server) GetMetrics(w http.ResponseWriter, r *http.Request) {
	defer watchman.Benchmark(time.Now(), "agenttype.metrics")

	agentType, err := findAgentType(r)
	if err != nil {
		respondWith404(w)
		return
	}

	orgID := agentType.OrganizationID.String()
	agentCounts, err := models.CountAgentsInStateForType(r.Context(), orgID, agentType.Name)
	if err != nil {
		log.Errorf("Error counting agents for %s (%s): %v", agentType.Name, orgID, err)
		_ = watchman.IncrementWithTags("server.error", []string{"db_error", orgID})
		respondWith500(w)
		return
	}

	jobCounts, err := zebraclient.CountByState(r.Context(), orgID, agentType.Name)
	if err != nil {
		log.Errorf("Error counting jobs for %s (%s): %v", agentType.Name, orgID, err)
		_ = watchman.IncrementWithTags("server.error", []string{"zebra_failure", orgID})
		respondWith500(w)
		return
	}

	metrics := AgentTypeMetrics{
		Jobs: buildOccupancyResponse(jobCounts),
		Agents: AgentOccupancy{
			Idle:     int32(agentCounts.Idle),
			Occupied: int32(agentCounts.Busy),
		},
	}

	err = respondWithJSON(w, http.StatusOK, metrics)
	if err != nil {
		respondWith500(w)
	}
}

// This endpoint is deprecated, and should be removed once there's no one using it
func (s *Server) GetOccupancy(w http.ResponseWriter, r *http.Request) {
	defer watchman.Benchmark(time.Now(), "agent.occupancy")

	agentType, err := findAgentType(r)
	if err != nil {
		respondWith404(w)
		return
	}

	countsByState, err := zebraclient.CountByState(r.Context(), agentType.OrganizationID.String(), agentType.Name)
	if err != nil {
		respondWith500(w)
		return
	}

	err = respondWithJSON(w, http.StatusOK, buildOccupancyResponse(countsByState))
	if err != nil {
		respondWith500(w)
	}
}

type ListJobsResponse struct {
	Jobs []zebraclient.Job `json:"jobs"`
}

func (s *Server) ListJobs(w http.ResponseWriter, r *http.Request) {
	defer watchman.Benchmark(time.Now(), "job.list")

	agentType, err := findAgentType(r)
	if err != nil {
		respondWith404(w)
		return
	}

	jobs, err := zebraclient.ListQueuedJobs(r.Context(), agentType.OrganizationID.String(), agentType.Name)
	if err != nil {
		log.Errorf("Error listing jobs for org %s and agent type %s: %v", agentType.OrganizationID, agentType.Name, err)
		_ = watchman.IncrementWithTags("server.error", []string{"zebra_failure", agentType.OrganizationID.String()})
		respondWith500(w)
		return
	}

	response := ListJobsResponse{
		Jobs: jobs,
	}

	err = respondWithJSON(w, http.StatusOK, response)
	if err != nil {
		respondWith500(w)
	}
}

func buildOccupancyResponse(countByState *zebra.CountByStateResponse) JobOccupancy {
	occupancy := JobOccupancy{}
	for _, count := range countByState.Counts {
		switch count.GetState() {
		case zebra.Job_ENQUEUED, zebra.Job_SCHEDULED:
			occupancy.Queued += count.GetCount()
		case zebra.Job_STARTED:
			occupancy.Running += count.GetCount()
		}
	}

	return occupancy
}

func (s *Server) Sync(w http.ResponseWriter, r *http.Request) {
	defer watchman.Benchmark(time.Now(), "agent.sync")

	request := &agentsync.Request{}

	err := json.NewDecoder(r.Body).Decode(request)
	if err != nil {
		respondWith422(w)
		return
	}

	orgID := r.Context().Value(orgIDKey).(string)
	tokenHash := r.Context().Value(tokenHashKey).(string)
	agent, err := models.SyncAgentWithContext(
		r.Context(),
		orgID,
		tokenHash,
		string(request.State),
		request.JobID,
		request.InterruptedAt,
	)

	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			respondWith404(w)
			return
		}

		log.Errorf("Error syncing agent for %s, %v: %v", orgID, request, err)
		_ = watchman.IncrementWithTags("server.error", []string{"sync_error", orgID})
		respondWith500(w)
		return
	}

	logging.ForAgent(agent).Debugf("Sync request: %v", request)

	response, err := agentsync.Process(r.Context(), s.quotaClient, s.agentCounter, s.publisher, agent, request)
	if err != nil {
		logging.ForAgent(agent).Errorf("Error processing sync request: %v", err)
		_ = watchman.IncrementWithTags("server.error", []string{"sync_error", orgID})
		respondWith500(w)
		return
	}

	logging.ForAgent(agent).Debugf("Sync response: %v", response)
	err = respondWithJSON(w, http.StatusOK, response)
	if err != nil {
		respondWith500(w)
	}
}

func (s *Server) Disconnect(w http.ResponseWriter, r *http.Request) {
	defer watchman.Benchmark(time.Now(), "agent.disconnect")

	agent, err := findAgent(r)
	if err != nil {
		respondWith404(w)
		return
	}

	agentType, err := models.FindAgentTypeWithContext(r.Context(), agent.OrganizationID, agent.AgentTypeName)
	if err != nil {
		respondWith404(w)
		return
	}

	logging.ForAgent(agent).Info("Disconnect requested")
	err = agent.DisconnectWithContext(r.Context())
	if err != nil {
		logging.ForAgent(agent).Errorf("Error disconnecting: %v", err)
		_ = watchman.IncrementWithTags("server.error", []string{"disconnect", agent.OrganizationID.String()})
		respondWith500(w)
		return
	}

	_ = s.publisher.PublishAuditLogEvent(r.Context(), agent, amqp.AuditLogOptions{
		UserID:      agentType.RequesterID,
		Operation:   audit.Event_Removed,
		Description: "Self-hosted agent disconnected",
	})

	logging.ForAgent(agent).Info("Successfully disconnected")
	err = respondWithString(w, http.StatusOK, "disconnected")
	if err != nil {
		respondWith500(w)
	}
}

func (s *Server) Serve(host string, port int) error {
	log.Infof("Starting server at %s:%d", host, port)
	s.httpServer = &http.Server{
		Addr:         fmt.Sprintf("%s:%d", host, port),
		ReadTimeout:  5 * time.Second,
		WriteTimeout: 30 * time.Second,
		IdleTimeout:  60 * time.Second,
		Handler: http.TimeoutHandler(
			handlers.LoggingHandler(os.Stdout, s.Router),
			s.timeoutHandlerTimeout,
			"request timed out",
		),
	}

	return s.httpServer.ListenAndServe()
}

func (s *Server) Close() {
	if err := s.httpServer.Close(); err != nil {
		log.Errorf("Error closing server: %v", err)
	}
}

func findAgent(r *http.Request) (*models.Agent, error) {
	orgID := r.Context().Value(orgIDKey).(string)
	tokenHash := r.Context().Value(tokenHashKey).(string)
	return models.FindAgentByTokenWithContext(r.Context(), orgID, tokenHash)
}

func findAgentType(r *http.Request) (*models.AgentType, error) {
	orgID := r.Context().Value(orgIDKey).(string)
	tokenHash := r.Context().Value(tokenHashKey).(string)
	return models.FindAgentTypeByTokenWithContext(r.Context(), orgID, tokenHash)
}

func (s *Server) assignAgentName(ctx context.Context, agentType *models.AgentType, nameFromAgent string) (string, error) {
	// Agent type requires name to come from agent,
	// so the name coming from the agent can't be a URL.
	if agentType.AgentNameSettings.NameAssignmentOrigin == models.NameAssignmentOriginFromAgent {
		if _, err := url.ParseRequestURI(nameFromAgent); err == nil {
			return "", fmt.Errorf("not allowed to use URLs for registration")
		}

		return models.ValidateAgentName(nameFromAgent)
	}

	// Agent type requires the name to come from AWS STS,
	// so if the URL isn't from AWS STS, we should still reject it.
	if parsedURL, err := url.ParseRequestURI(nameFromAgent); err != nil || !aws.IsSTSURL(parsedURL) {
		return "", fmt.Errorf("only pre-signed AWS STS URLs for name assignment are allowed")
	}

	logging.ForAgentType(agentType).Info("Following AWS STS URL to assign agent name")
	rolePatterns := strings.Split(agentType.AgentNameSettings.AWSRoleNamePatterns, ",")
	return aws.AssignNameFromSTS(
		ctx,
		s.httpClient,
		agentType.AgentNameSettings.AWSAccount,
		rolePatterns,
		nameFromAgent,
	)
}
