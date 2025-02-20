package internalapi

import (
	"context"
	"errors"
	"fmt"
	"regexp"
	"strings"
	"time"

	"github.com/renderedtext/go-watchman"
	"github.com/semaphoreio/semaphore/self_hosted_hub/pkg/agentsync"
	models "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/models"
	"github.com/semaphoreio/semaphore/self_hosted_hub/pkg/quotas"

	pb "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/protos/self_hosted"

	uuid "github.com/google/uuid"
	logging "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/logging"
	log "github.com/sirupsen/logrus"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/timestamppb"
	gorm "gorm.io/gorm"
)

var agentTypeNameRegex = regexp.MustCompile("^s1-[a-zA-Z0-9-_]+$")
var minAgentPageSize int32 = 5
var maxAgentPageSize int32 = 200

type SelfHostedService struct {
	quotaClient *quotas.QuotaClient
}

func NewSelfHostedService(quotaClient *quotas.QuotaClient) *SelfHostedService {
	return &SelfHostedService{quotaClient: quotaClient}
}

func (s *SelfHostedService) Describe(ctx context.Context, request *pb.DescribeRequest) (*pb.DescribeResponse, error) {
	defer watchman.BenchmarkWithTags(time.Now(), "internalapi.Describe", []string{})

	log.Infof("Describe: %v", request)

	orgID, err := uuid.Parse(request.OrganizationId)
	if err != nil {
		log.Errorf("Error reading organization id on %v for Describe: %v", request, err)
		return nil, err
	}

	agentType, err := models.FindAgentTypeWithAgentCount(orgID, request.Name)
	if err != nil {
		log.Errorf("Error on Describe for %v: %v", request, err)

		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, status.Error(codes.NotFound, "agent type not found")
		}

		return nil, err
	}

	response := &pb.DescribeResponse{
		AgentType: s.serializeAgentType(agentType),
	}

	return response, nil
}

func (s *SelfHostedService) DescribeAgent(ctx context.Context, request *pb.DescribeAgentRequest) (*pb.DescribeAgentResponse, error) {
	defer watchman.BenchmarkWithTags(time.Now(), "internalapi.DescribeAgent", []string{})

	log.Infof("DescribeAgent: %v", request)

	orgID, err := uuid.Parse(request.OrganizationId)
	if err != nil {
		log.Errorf("Error reading organization id on %v for DescribeAgent: %v", request, err)
		return nil, err
	}

	agent, err := models.FindAgentByName(orgID.String(), request.Name)
	if err != nil {
		log.Errorf("Error on DescribeAgent for %v: %v", request, err)

		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, status.Error(codes.NotFound, "agent not found")
		}

		return nil, err
	}

	response := &pb.DescribeAgentResponse{
		Agent: s.serializeAgent(agent),
	}

	return response, nil
}

func (s *SelfHostedService) ListKeyset(ctx context.Context, request *pb.ListKeysetRequest) (*pb.ListKeysetResponse, error) {
	defer watchman.BenchmarkWithTags(time.Now(), "internalapi.ListKeyset", []string{})

	log.Infof("ListKeyset: %v", request)

	orgID, err := uuid.Parse(request.OrganizationId)
	if err != nil {
		log.Errorf("Error reading organization id on %v for ListKeyset: %v", request, err)
		return nil, err
	}

	agentTypes, nextCursor, err := models.ListCursorAgentTypesWithAgentCount(orgID, request.PageSize, request.Cursor)
	if err != nil {
		log.Errorf("Error on ListKeyset for %v: %v", request, err)
		return nil, status.Error(codes.Unknown, err.Error())
	}

	res := &pb.ListKeysetResponse{
		AgentTypes:     s.serializeAgentTypes(agentTypes),
		NextPageCursor: nextCursor,
	}

	return res, nil
}

func (s *SelfHostedService) List(ctx context.Context, request *pb.ListRequest) (*pb.ListResponse, error) {
	defer watchman.BenchmarkWithTags(time.Now(), "internalapi.List", []string{})

	log.Infof("List: %v", request)

	orgID, err := uuid.Parse(request.OrganizationId)
	if err != nil {
		log.Errorf("Error reading organization id on %v for List: %v", request, err)
		return nil, err
	}

	agentTypes, err := models.ListAgentTypesWithAgentCount(orgID)
	if err != nil {
		log.Errorf("Error on List for %v: %v", request, err)
		return nil, status.Error(codes.Unknown, err.Error())
	}

	res := &pb.ListResponse{
		AgentTypes: s.serializeAgentTypes(agentTypes),
	}

	return res, nil
}

func (s *SelfHostedService) ListAgents(ctx context.Context, request *pb.ListAgentsRequest) (*pb.ListAgentsResponse, error) {
	defer watchman.BenchmarkWithTags(time.Now(), "internalapi.ListAgents", []string{})

	log.Infof("ListAgents: %v", request)

	orgID, err := uuid.Parse(request.OrganizationId)
	if err != nil {
		log.Errorf("Error reading organization id on %v for ListAgents: %v", request, err)
		return nil, err
	}

	pageSize := request.PageSize
	if pageSize == 0 {
		pageSize = maxAgentPageSize
	}

	if pageSize < minAgentPageSize || pageSize > maxAgentPageSize {
		return nil, status.Error(
			codes.InvalidArgument,
			fmt.Sprintf(
				"page size of %d is invalid: must be greater than 0 and between %d-%d",
				request.PageSize,
				minAgentPageSize,
				maxAgentPageSize,
			),
		)
	}

	agents, nextCursor, err := models.ListAgentsWithCursor(orgID, request.AgentTypeName, pageSize, request.Cursor)
	if err != nil {
		log.Errorf("Error on ListAgents for %v: %v", request, err)
		return nil, status.Error(codes.Unknown, err.Error())
	}

	res := &pb.ListAgentsResponse{
		Agents: s.serializeAgents(agents),
	}

	if nextCursor != "" {
		res.Cursor = nextCursor
	}

	return res, nil
}

func (s *SelfHostedService) Create(ctx context.Context, request *pb.CreateRequest) (*pb.CreateResponse, error) {
	defer watchman.BenchmarkWithTags(time.Now(), "internalapi.Create", []string{})

	log.Infof("Create: %v", request)

	orgID, err := uuid.Parse(request.OrganizationId)
	if err != nil {
		log.Errorf("Error reading organization id on %v for Create: %v", request, err)
		return nil, err
	}

	requesterID, err := uuid.Parse(request.RequesterId)
	if err != nil {
		log.Errorf("Error reading requester id on %v for Create: %v", request, err)
		return nil, err
	}

	agentTypeName := strings.Trim(request.Name, " ")
	if !agentTypeNameRegex.MatchString(agentTypeName) {
		return nil, status.Error(
			codes.InvalidArgument,
			fmt.Sprintf("The agent type name '%s' is invalid: must follow the pattern %s", request.Name, agentTypeNameRegex.String()),
		)
	}

	orgQuota, err := s.quotaClient.GetQuota(orgID.String())
	if err != nil {
		log.Errorf("Error finding organization quota on %v for Create: %v", request, err)
		return nil, err
	}

	if !orgQuota.Enabled {
		return nil, status.Error(codes.FailedPrecondition, "self-hosted agents are not available for your organization")
	}

	nameSettings, err := models.NewAgentNameSettings(request.AgentNameSettings)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, err.Error())
	}

	agentType, token, err := models.CreateAgentTypeWithSettings(orgID, &requesterID, agentTypeName, *nameSettings)
	if err != nil {
		log.Errorf("Error on Create for %v: %v", request, err)
		if err.Error() == "agent type name must by unique in the organization" {
			return nil, status.Error(codes.AlreadyExists, err.Error())
		}
		return nil, err
	}

	agentTypeWithAgentCount := models.AgentTypeWithAgentCount{
		AgentType:       agentType,
		TotalAgentCount: 0,
	}

	response := &pb.CreateResponse{
		AgentType:              s.serializeAgentType(&agentTypeWithAgentCount),
		AgentRegistrationToken: token,
	}

	return response, nil
}

func (s *SelfHostedService) Update(ctx context.Context, request *pb.UpdateRequest) (*pb.UpdateResponse, error) {
	defer watchman.BenchmarkWithTags(time.Now(), "internalapi.update", []string{})

	log.Infof("Update: %s, %s", request.OrganizationId, request.Name)

	orgID, err := uuid.Parse(request.OrganizationId)
	if err != nil {
		log.Errorf("Error reading organization id on %v for Update: %v", request, err)
		return nil, err
	}

	requesterID, err := uuid.Parse(request.RequesterId)
	if err != nil {
		log.Errorf("Error reading requester id on %v for Update: %v", request, err)
		return nil, err
	}

	agentType, err := models.FindAgentType(orgID, request.Name)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, status.Error(codes.NotFound, err.Error())
		}

		log.Errorf("Error finding agent type for update: %v", err)
		return nil, status.Error(codes.Internal, err.Error())
	}

	newNameSettings, err := models.NewAgentNameSettings(request.AgentType.AgentNameSettings)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, err.Error())
	}

	agentType.AgentNameSettings = *newNameSettings
	agentType.RequesterID = &requesterID

	err = agentType.Update()
	if err != nil {
		log.Errorf("Error on Update for %v: %v", request, err)
		return nil, status.Error(codes.Internal, err.Error())
	}

	agentTypeWithAgentCount := models.AgentTypeWithAgentCount{
		AgentType:       agentType,
		TotalAgentCount: 0,
	}

	response := &pb.UpdateResponse{
		AgentType: s.serializeAgentType(&agentTypeWithAgentCount),
	}

	return response, nil
}

func (s *SelfHostedService) OccupyAgent(ctx context.Context, request *pb.OccupyAgentRequest) (*pb.OccupyAgentResponse, error) {
	defer watchman.BenchmarkWithTags(time.Now(), "internalapi.OccupyAgent", []string{})

	log.Infof("OccupyAgent: %v", request)

	orgID, err := uuid.Parse(request.OrganizationId)
	if err != nil {
		log.Errorf("Error reading organization id on %v for OccupyAgent: %v", request, err)
		return nil, err
	}

	jobID, err := uuid.Parse(request.JobId)
	if err != nil {
		log.Errorf("Error reading job id on %v for OccupyAgent: %v", request, err)
		return nil, err
	}

	err = models.CreateOccupationRequest(orgID, request.AgentType, jobID)
	if err != nil {
		log.Errorf("Error on OccupyAgent for %v: %v", request, err)
		return nil, err
	}

	// We send an empty response back. Once an agent becomes available,
	// a `job_started` callback will be sent with the agent information.
	return &pb.OccupyAgentResponse{}, nil
}

func (s *SelfHostedService) ReleaseAgent(ctx context.Context, request *pb.ReleaseAgentRequest) (*pb.ReleaseAgentResponse, error) {
	defer watchman.BenchmarkWithTags(time.Now(), "internalapi.ReleaseAgent", []string{})

	log.Infof("ReleaseAgent: %v", request)

	orgID, err := uuid.Parse(request.OrganizationId)
	if err != nil {
		log.Errorf("Error reading organization id on %v for ReleaseAgent: %v", request, err)
		return nil, err
	}

	jobID, err := uuid.Parse(request.JobId)
	if err != nil {
		log.Errorf("Error reading job id on %v for ReleaseAgent: %v", request, err)
		return nil, err
	}

	_, err = models.ReleaseAgent(orgID, request.AgentType, jobID)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			log.Errorf("Couldn't find agent to release for %v - ignoring", request)
		} else {
			log.Errorf("Error on ReleaseAgent for %v: %v", request, err)
			return nil, err
		}
	}

	return &pb.ReleaseAgentResponse{}, nil
}

func (s *SelfHostedService) DisableAgent(ctx context.Context, request *pb.DisableAgentRequest) (*pb.DisableAgentResponse, error) {
	defer watchman.BenchmarkWithTags(time.Now(), "internalapi.DisableAgent", []string{})

	log.Infof("DisableAgent: %v", request)

	orgID, err := uuid.Parse(request.OrganizationId)
	if err != nil {
		log.Errorf("Error reading organization id on %v for DisableAgent: %v", request, err)
		return nil, err
	}

	_, err = models.DisableAgent(orgID, request.AgentType, request.AgentName)
	if err != nil {
		log.Printf("Error on DisableAgent for %v: %v", request, err)
		return nil, err
	}

	return &pb.DisableAgentResponse{}, nil
}

func (s *SelfHostedService) DisableAllAgents(ctx context.Context, request *pb.DisableAllAgentsRequest) (*pb.DisableAllAgentsResponse, error) {
	defer watchman.BenchmarkWithTags(time.Now(), "internalapi.DisableAllAgents", []string{})

	log.Infof("DisableAllAgents: %v", request)

	orgID, err := uuid.Parse(request.OrganizationId)
	if err != nil {
		log.Errorf("Error reading organization id on %v for DisableAllAgents: %v", request, err)
		return nil, err
	}

	if request.OnlyIdle {
		err = models.DisableOnlyIdleAgents(orgID, request.AgentType)
		if err != nil {
			log.Errorf("Error on DisableAllAgents for idle agents for %v: %v", request, err)
			return nil, err
		}
	} else {
		err = models.DisableAllAgents(orgID, request.AgentType)
		if err != nil {
			log.Errorf("Error on DisableAllAgents for %v: %v", request, err)
			return nil, err
		}
	}

	return &pb.DisableAllAgentsResponse{}, nil
}

func (s *SelfHostedService) DeleteAgentType(ctx context.Context, request *pb.DeleteAgentTypeRequest) (*pb.DeleteAgentTypeResponse, error) {
	defer watchman.BenchmarkWithTags(time.Now(), "internalapi.DeleteAgentType", []string{})

	log.Infof("DeleteAgentType: %v", request)

	orgID, err := uuid.Parse(request.OrganizationId)
	if err != nil {
		log.Errorf("Error reading organization id on %v for DeleteAgentType: %v", request, err)
		return nil, err
	}

	agentType, err := models.FindAgentType(orgID, request.Name)
	if err != nil {
		log.Errorf("Error finding agent type on DeleteAgentType for %v: %v", request, err)
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, status.Error(codes.NotFound, "agent type not found")
		}

		return nil, err
	}

	err = agentType.Delete()
	if err != nil {
		logging.ForAgentType(agentType).Errorf("Error when deleting: %v", err)
		if errors.Is(err, models.ErrCantDeleteAgentTypeWithExistingAgents) {
			return nil, status.Error(codes.FailedPrecondition, err.Error())
		}

		return nil, err
	}

	return &pb.DeleteAgentTypeResponse{}, nil
}

func (s *SelfHostedService) StopJob(ctx context.Context, request *pb.StopJobRequest) (*pb.StopJobResponse, error) {
	defer watchman.BenchmarkWithTags(time.Now(), "internalapi.StopJob", []string{})

	log.Infof("StopJob: %v", request)

	orgID, err := uuid.Parse(request.OrganizationId)
	if err != nil {
		log.Errorf("Error reading organization id on %v for StopJob: %v", request, err)
		return nil, err
	}

	jobID, err := uuid.Parse(request.JobId)
	if err != nil {
		log.Errorf("Error reading job id on %v for StopJob: %v", request, err)
		return nil, err
	}

	err = models.StopJob(orgID, jobID)
	if err != nil {
		log.Errorf("Error on StopJob for %v: %v", request, err)
		return nil, err
	}

	return &pb.StopJobResponse{}, nil
}

func (s *SelfHostedService) ResetToken(ctx context.Context, request *pb.ResetTokenRequest) (*pb.ResetTokenResponse, error) {
	defer watchman.BenchmarkWithTags(time.Now(), "internalapi.ResetToken", []string{})

	log.Infof("ResetToken: %v", request)

	orgID, err := uuid.Parse(request.OrganizationId)
	if err != nil {
		log.Errorf("Error reading organization id on %v for ResetToken: %v", request, err)
		return nil, err
	}

	requesterID, err := uuid.Parse(request.RequesterId)
	if err != nil {
		log.Errorf("Error reading requester id on %v for ResetToken: %v", request, err)
		return nil, err
	}

	agentType, err := models.FindAgentType(orgID, request.AgentType)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, status.Error(codes.NotFound, "agent type not found")
		}

		log.Errorf("Error finding agent type on ResetToken for %v: %v", request, err)
		return nil, err
	}

	token, err := agentType.ResetToken(&requesterID)
	if err != nil {
		logging.ForAgentType(agentType).Errorf("Error on reset token: %v", err)
		return nil, err
	}

	if request.DisconnectRunningAgents {
		logging.ForAgentType(agentType).Infof("Disabling all agents")

		err := models.DisableAllAgents(orgID, request.AgentType)
		if err != nil {
			logging.ForAgentType(agentType).Errorf("Error disabling all agents: %v", err)
			return nil, err
		}
	}

	return &pb.ResetTokenResponse{Token: token}, nil
}

func (s *SelfHostedService) serializeAgentType(agentType *models.AgentTypeWithAgentCount) *pb.AgentType {
	t := &pb.AgentType{
		OrganizationId:  agentType.AgentType.OrganizationID.String(),
		Name:            agentType.AgentType.Name,
		TotalAgentCount: int32(agentType.TotalAgentCount),
		CreatedAt:       timestamppb.New(*agentType.AgentType.CreatedAt),
		UpdatedAt:       timestamppb.New(*agentType.AgentType.UpdatedAt),
	}

	if agentType.AgentType.NameAssignmentOrigin == models.NameAssignmentOriginFromAgent {
		t.AgentNameSettings = &pb.AgentNameSettings{
			AssignmentOrigin: pb.AgentNameSettings_ASSIGNMENT_ORIGIN_AGENT,
			ReleaseAfter:     agentType.AgentType.ReleaseNameAfter,
		}
	} else {
		t.AgentNameSettings = &pb.AgentNameSettings{
			AssignmentOrigin: pb.AgentNameSettings_ASSIGNMENT_ORIGIN_AWS_STS,
			ReleaseAfter:     agentType.AgentType.ReleaseNameAfter,
			Aws: &pb.AgentNameSettings_AWS{
				AccountId:        agentType.AgentType.AWSAccount,
				RoleNamePatterns: agentType.AgentType.AWSRoleNamePatterns,
			},
		}
	}

	if agentType.AgentType.RequesterID != nil {
		t.RequesterId = agentType.AgentType.RequesterID.String()
	}

	return t
}

func (s *SelfHostedService) serializeAgentTypes(agentTypes []models.AgentTypeWithAgentCount) []*pb.AgentType {
	result := []*pb.AgentType{}

	for i := range agentTypes {
		result = append(result, s.serializeAgentType(&agentTypes[i]))
	}

	return result
}

func (s *SelfHostedService) serializeAgents(agents []models.Agent) []*pb.Agent {
	result := []*pb.Agent{}

	for i := range agents {
		result = append(result, s.serializeAgent(&agents[i]))
	}

	return result
}

func (s *SelfHostedService) serializeAgent(agent *models.Agent) *pb.Agent {
	serializedAgent := pb.Agent{
		Name:           agent.Name,
		Version:        agent.Version,
		OrganizationId: agent.OrganizationID.String(),
		Os:             agent.OS,
		Hostname:       agent.Hostname,
		IpAddress:      agent.IPAddress,
		UserAgent:      agent.UserAgent,
		Arch:           agent.Arch,
		Pid:            int32(agent.PID),
		State:          s.serializeAgentState(agent),
		ConnectedAt:    timestamppb.New(*agent.CreatedAt),
		TypeName:       agent.AgentTypeName,
	}

	if agent.DisabledAt != nil {
		serializedAgent.Disabled = true
		serializedAgent.DisabledAt = timestamppb.New(*agent.DisabledAt)
	}

	return &serializedAgent
}

func (s *SelfHostedService) serializeAgentState(agent *models.Agent) pb.Agent_State {
	if agent.LastSyncState == "" || agent.LastSyncState == agentsync.AgentStateWaitingForJobs {
		return pb.Agent_WAITING_FOR_JOB
	}

	return pb.Agent_RUNNING_JOB
}
