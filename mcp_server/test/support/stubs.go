package support

import (
	"context"
	"fmt"
	"strings"
	"sync"
	"time"

	"github.com/semaphoreio/semaphore/mcp_server/pkg/feature"
	artifacthubpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/artifacthub"
	featurepb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/feature"
	loghubpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/loghub"
	loghub2pb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/loghub2"
	orgpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/organization"
	pipelinepb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/plumber.pipeline"
	workflowpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/plumber_w_f.workflow"
	projecthubpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/projecthub"
	rbacpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/rbac"
	responsepb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/response_status"
	jobpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/server_farm.job"
	statuspb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/status"
	userpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/user"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/internalapi"
	featuresvc "github.com/semaphoreio/semaphore/mcp_server/pkg/service"

	code "google.golang.org/genproto/googleapis/rpc/code"
	"google.golang.org/grpc"
	"google.golang.org/protobuf/types/known/timestamppb"
)

// New returns an internalapi.Provider backed by deterministic stub responses useful for local development.
func New() internalapi.Provider {
	return &provider{
		timeout:       time.Second,
		workflows:     &WorkflowClientStub{},
		organizations: &organizationStub{},
		projects:      &ProjectClientStub{},
		pipelines:     &pipelineStub{},
		jobs:          &jobStub{},
		loghub:        &loghubStub{},
		loghub2:       &loghub2Stub{},
		users:         &UserClientStub{},
		rbac:          &RBACStub{},
		features:      &featureStub{},
	}
}

type provider struct {
	timeout       time.Duration
	workflows     workflowpb.WorkflowServiceClient
	organizations orgpb.OrganizationServiceClient
	projects      projecthubpb.ProjectServiceClient
	pipelines     pipelinepb.PipelineServiceClient
	jobs          jobpb.JobServiceClient
	artifacthub   artifacthubpb.ArtifactServiceClient
	loghub        loghubpb.LoghubClient
	loghub2       loghub2pb.Loghub2Client
	users         userpb.UserServiceClient
	rbac          rbacpb.RBACClient
	features      featuresvc.FeatureClient
}

func (p *provider) CallTimeout() time.Duration { return p.timeout }

func (p *provider) Workflow() workflowpb.WorkflowServiceClient { return p.workflows }

func (p *provider) Organizations() orgpb.OrganizationServiceClient { return p.organizations }

func (p *provider) Projects() projecthubpb.ProjectServiceClient { return p.projects }

func (p *provider) Pipelines() pipelinepb.PipelineServiceClient { return p.pipelines }

func (p *provider) Jobs() jobpb.JobServiceClient { return p.jobs }

func (p *provider) Artifacthub() artifacthubpb.ArtifactServiceClient { return p.artifacthub }

func (p *provider) Loghub() loghubpb.LoghubClient { return p.loghub }

func (p *provider) Loghub2() loghub2pb.Loghub2Client { return p.loghub2 }

func (p *provider) Users() userpb.UserServiceClient { return p.users }

func (p *provider) RBAC() rbacpb.RBACClient { return p.rbac }

func (p *provider) Features() featuresvc.FeatureClient { return p.features }

// --- pipeline stub ---

type pipelineStub struct {
	pipelinepb.PipelineServiceClient
}

func (p *pipelineStub) ListKeyset(ctx context.Context, in *pipelinepb.ListKeysetRequest, opts ...grpc.CallOption) (*pipelinepb.ListKeysetResponse, error) {
	return &pipelinepb.ListKeysetResponse{
		Pipelines: []*pipelinepb.Pipeline{
			{
				PplId:          "ppl-local",
				Name:           "Build",
				WfId:           orDefault(in.GetWfId(), "wf-local"),
				ProjectId:      orDefault(in.GetProjectId(), "project-local"),
				OrganizationId: "org-local",
				BranchName:     "main",
				CommitSha:      "abcdef0",
				State:          pipelinepb.Pipeline_RUNNING,
				Result:         pipelinepb.Pipeline_PASSED,
				ResultReason:   pipelinepb.Pipeline_TEST,
				CreatedAt:      timestamppb.New(time.Unix(1_700_000_000, 0)),
				Queue:          &pipelinepb.Queue{QueueId: "queue-local", Name: "default", Type: pipelinepb.QueueType_IMPLICIT},
				Triggerer:      &pipelinepb.Triggerer{PplTriggeredBy: pipelinepb.TriggeredBy_WORKFLOW},
			},
		},
	}, nil
}

func (p *pipelineStub) Describe(ctx context.Context, in *pipelinepb.DescribeRequest, opts ...grpc.CallOption) (*pipelinepb.DescribeResponse, error) {
	return &pipelinepb.DescribeResponse{
		ResponseStatus: &pipelinepb.ResponseStatus{Code: pipelinepb.ResponseStatus_OK},
		Pipeline: &pipelinepb.Pipeline{
			PplId:          orDefault(in.GetPplId(), "ppl-local"),
			Name:           "Build",
			ProjectId:      "project-local",
			OrganizationId: "org-local",
			WfId:           "wf-local",
		},
		Blocks: []*pipelinepb.Block{
			{
				BlockId:      "block-local",
				Name:         "Tests",
				State:        pipelinepb.Block_RUNNING,
				Result:       pipelinepb.Block_PASSED,
				ResultReason: pipelinepb.Block_TEST,
				Jobs: []*pipelinepb.Block_Job{{
					Name:  "job-local",
					JobId: "job-local",
				}},
			},
		},
	}, nil
}

// --- job stub ---

type jobStub struct {
	jobpb.JobServiceClient
}

func (j *jobStub) Describe(ctx context.Context, in *jobpb.DescribeRequest, opts ...grpc.CallOption) (*jobpb.DescribeResponse, error) {
	return &jobpb.DescribeResponse{
		Status: &responsepb.ResponseStatus{Code: responsepb.ResponseStatus_OK},
		Job: &jobpb.Job{
			Id:             orDefault(in.GetJobId(), "job-local"),
			Name:           "Test job",
			PplId:          "ppl-local",
			ProjectId:      "project-local",
			OrganizationId: "org-local",
			Timeline: &jobpb.Job_Timeline{
				CreatedAt: timestamppb.New(time.Unix(1_700_000_000, 0)),
			},
		},
	}, nil
}

// --- loghub stub ---

type loghubStub struct {
	loghubpb.LoghubClient
}

func (l *loghubStub) GetLogEvents(ctx context.Context, in *loghubpb.GetLogEventsRequest, opts ...grpc.CallOption) (*loghubpb.GetLogEventsResponse, error) {
	return &loghubpb.GetLogEventsResponse{
		Status: &responsepb.ResponseStatus{Code: responsepb.ResponseStatus_OK},
		Events: []string{"starting job", "running tests", "done"},
		Final:  true,
	}, nil
}

// --- loghub2 stub ---

type loghub2Stub struct {
	loghub2pb.Loghub2Client
}

func (l *loghub2Stub) GenerateToken(ctx context.Context, in *loghub2pb.GenerateTokenRequest, opts ...grpc.CallOption) (*loghub2pb.GenerateTokenResponse, error) {
	return &loghub2pb.GenerateTokenResponse{Token: "stub-token", Type: loghub2pb.TokenType_PULL}, nil
}

func orDefault(value, fallback string) string {
	if value != "" {
		return value
	}
	return fallback
}

// --- organization stub ---

type organizationStub struct {
	orgpb.OrganizationServiceClient
}

func (o *organizationStub) Describe(ctx context.Context, in *orgpb.DescribeRequest, opts ...grpc.CallOption) (*orgpb.DescribeResponse, error) {
	orgID := in.GetOrgId()
	if orgID == "" {
		orgID = "org-local"
	}
	return &orgpb.DescribeResponse{
		Status: &responsepb.ResponseStatus{Code: responsepb.ResponseStatus_OK},
		Organization: &orgpb.Organization{
			OrgId:       orgID,
			Name:        "Local Org",
			OrgUsername: "local-org",
			OwnerId:     "user-local",
		},
	}, nil
}

func (o *organizationStub) List(ctx context.Context, in *orgpb.ListRequest, opts ...grpc.CallOption) (*orgpb.ListResponse, error) {
	return &orgpb.ListResponse{
		Status: &responsepb.ResponseStatus{Code: responsepb.ResponseStatus_OK},
		Organizations: []*orgpb.Organization{
			{
				OrgId:       "org-local",
				Name:        "Local Org",
				OrgUsername: "local-org",
				OwnerId:     "user-local",
				CreatedAt:   timestamppb.New(time.Unix(1_700_000_000, 0)),
				Verified:    true,
			},
		},
		NextPageToken: "",
	}, nil
}

func (o *organizationStub) DescribeMany(ctx context.Context, in *orgpb.DescribeManyRequest, opts ...grpc.CallOption) (*orgpb.DescribeManyResponse, error) {
	return &orgpb.DescribeManyResponse{
		Organizations: []*orgpb.Organization{
			{
				OrgId:       "org-local",
				Name:        "Local Org",
				OrgUsername: "local-org",
				OwnerId:     "user-local",
				CreatedAt:   timestamppb.New(time.Unix(1_700_000_000, 0)),
				Verified:    true,
			},
		},
	}, nil
}

// --- features stub ---

type featureStub struct {
	featuresvc.FeatureClient
}

func (f *featureStub) ListOrganizationFeatures(organizationId string) ([]feature.OrganizationFeature, error) {
	return []feature.OrganizationFeature{
		{
			Name:     "feature-a",
			State:    feature.Enabled,
			Quantity: 10,
		},
		{
			Name:     "feature-b",
			State:    feature.Hidden,
			Quantity: 0,
		},
		{
			Name:     "mcp_server_read_tools",
			State:    feature.Enabled,
			Quantity: 1,
		},
	}, nil
}

func (f *featureStub) FeatureState(organizationId string, featureName string) (feature.State, error) {
	switch featureName {
	case "feature-a", "mcp_server_read_tools":
		return feature.Enabled, nil
	case "feature-b":
		return feature.Hidden, nil
	}
	return feature.Hidden, nil
}

// --- feature hub service stub ---

type FeatureHubServiceStub struct {
	featurepb.UnimplementedFeatureServiceServer

	mu          sync.Mutex
	response    *featurepb.ListOrganizationFeaturesResponse
	err         error
	lastRequest *featurepb.ListOrganizationFeaturesRequest
	callCount   int
}

func NewFeatureHubServiceStub() *FeatureHubServiceStub {
	return &FeatureHubServiceStub{}
}

func (s *FeatureHubServiceStub) SetResponse(response *featurepb.ListOrganizationFeaturesResponse) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.response = response
}

func (s *FeatureHubServiceStub) SetError(err error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.err = err
}

func (s *FeatureHubServiceStub) ListOrganizationFeatures(ctx context.Context, req *featurepb.ListOrganizationFeaturesRequest) (*featurepb.ListOrganizationFeaturesResponse, error) {
	s.mu.Lock()
	s.lastRequest = req
	s.callCount++
	response := s.response
	err := s.err
	s.mu.Unlock()

	if err != nil {
		return nil, err
	}
	if response != nil {
		return response, nil
	}
	return &featurepb.ListOrganizationFeaturesResponse{}, nil
}

func (s *FeatureHubServiceStub) LastRequest() *featurepb.ListOrganizationFeaturesRequest {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.lastRequest
}

func (s *FeatureHubServiceStub) CallCount() int {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.callCount
}

// --- workflow tool focused stubs ---

// WorkflowClientStub records workflow RPC requests and returns configurable responses.
type WorkflowClientStub struct {
	workflowpb.WorkflowServiceClient

	ListResp         *workflowpb.ListKeysetResponse
	ListErr          error
	LastList         *workflowpb.ListKeysetRequest
	ScheduleResp     *workflowpb.ScheduleResponse
	ScheduleErr      error
	LastSchedule     *workflowpb.ScheduleRequest
	RescheduleResp   *workflowpb.ScheduleResponse
	RescheduleErr    error
	LastReschedule   *workflowpb.RescheduleRequest
	GetProjectResp   *workflowpb.GetProjectIdResponse
	GetProjectErr    error
	LastGetProjectId *workflowpb.GetProjectIdRequest
	DescribeResp     *workflowpb.DescribeResponse
	DescribeErr      error
	LastDescribe     *workflowpb.DescribeRequest
}

func (s *WorkflowClientStub) Schedule(ctx context.Context, in *workflowpb.ScheduleRequest, opts ...grpc.CallOption) (*workflowpb.ScheduleResponse, error) {
	s.LastSchedule = in
	if s.ScheduleErr != nil {
		return nil, s.ScheduleErr
	}
	if s.ScheduleResp != nil {
		return s.ScheduleResp, nil
	}
	return &workflowpb.ScheduleResponse{Status: &statuspb.Status{Code: code.Code_OK}}, nil
}

func (s *WorkflowClientStub) ListKeyset(ctx context.Context, in *workflowpb.ListKeysetRequest, opts ...grpc.CallOption) (*workflowpb.ListKeysetResponse, error) {
	s.LastList = in
	if s.ListErr != nil {
		return nil, s.ListErr
	}
	if s.ListResp != nil {
		return s.ListResp, nil
	}
	projectID := "project-local"
	if in != nil && strings.TrimSpace(in.GetProjectId()) != "" {
		projectID = in.GetProjectId()
	}
	return &workflowpb.ListKeysetResponse{
		Status: &statuspb.Status{Code: code.Code_OK},
		Workflows: []*workflowpb.WorkflowDetails{
			{
				WfId:           "wf-local",
				InitialPplId:   "ppl-local",
				ProjectId:      projectID,
				BranchName:     "main",
				CommitSha:      "abcdef0",
				CreatedAt:      timestamppb.New(time.Unix(1_700_000_000, 0)),
				TriggeredBy:    workflowpb.TriggeredBy_MANUAL_RUN,
				OrganizationId: "org-local",
			},
		},
		NextPageToken: "",
	}, nil
}

func (s *WorkflowClientStub) Reschedule(ctx context.Context, in *workflowpb.RescheduleRequest, opts ...grpc.CallOption) (*workflowpb.ScheduleResponse, error) {
	s.LastReschedule = in
	if s.RescheduleErr != nil {
		return nil, s.RescheduleErr
	}
	if s.RescheduleResp != nil {
		return s.RescheduleResp, nil
	}
	return &workflowpb.ScheduleResponse{Status: &statuspb.Status{Code: code.Code_OK}, WfId: "wf-rerun", PplId: "ppl-rerun"}, nil
}

func (s *WorkflowClientStub) GetProjectId(ctx context.Context, in *workflowpb.GetProjectIdRequest, opts ...grpc.CallOption) (*workflowpb.GetProjectIdResponse, error) {
	s.LastGetProjectId = in
	if s.GetProjectErr != nil {
		return nil, s.GetProjectErr
	}
	if s.GetProjectResp != nil {
		return s.GetProjectResp, nil
	}
	return &workflowpb.GetProjectIdResponse{
		Status:    &statuspb.Status{Code: code.Code_OK},
		ProjectId: "project-local",
	}, nil
}

func (s *WorkflowClientStub) Describe(ctx context.Context, in *workflowpb.DescribeRequest, opts ...grpc.CallOption) (*workflowpb.DescribeResponse, error) {
	s.LastDescribe = in
	if s.DescribeErr != nil {
		return nil, s.DescribeErr
	}
	if s.DescribeResp != nil {
		return s.DescribeResp, nil
	}
	return &workflowpb.DescribeResponse{
		Status: &statuspb.Status{Code: code.Code_OK},
		Workflow: &workflowpb.WorkflowDetails{
			WfId:           orDefault(in.GetWfId(), "wf-local"),
			ProjectId:      "project-local",
			OrganizationId: "org-local",
		},
	}, nil
}

// ProjectClientStub records describe requests and returns configurable responses.
type ProjectClientStub struct {
	projecthubpb.ProjectServiceClient

	Response     *projecthubpb.DescribeResponse
	Err          error
	LastDescribe *projecthubpb.DescribeRequest
	ListResponse *projecthubpb.ListResponse
	ListErr      error
}

func (s *ProjectClientStub) Describe(ctx context.Context, in *projecthubpb.DescribeRequest, opts ...grpc.CallOption) (*projecthubpb.DescribeResponse, error) {
	s.LastDescribe = in
	if s.Err != nil {
		return nil, s.Err
	}
	if s.Response != nil {
		return s.Response, nil
	}
	orgID := "org-local"
	projectID := "project-local"
	if in != nil {
		if pid := strings.TrimSpace(in.GetId()); pid != "" {
			projectID = pid
		}
	}
	return NewProjectDescribeResponse(orgID, projectID, &projecthubpb.Project_Spec_Repository{
		PipelineFile: ".semaphore/semaphore.yml",
	}), nil
}

func (s *ProjectClientStub) List(ctx context.Context, in *projecthubpb.ListRequest, opts ...grpc.CallOption) (*projecthubpb.ListResponse, error) {
	if s.ListErr != nil {
		return nil, s.ListErr
	}
	if s.ListResponse != nil {
		return s.ListResponse, nil
	}
	page := int32(0)
	size := int32(0)
	if in != nil && in.GetPagination() != nil {
		page = in.GetPagination().GetPage()
		size = in.GetPagination().GetPageSize()
	}
	return &projecthubpb.ListResponse{
		Metadata: &projecthubpb.ResponseMeta{
			Status: &projecthubpb.ResponseMeta_Status{Code: projecthubpb.ResponseMeta_OK},
		},
		Pagination: &projecthubpb.PaginationResponse{
			PageNumber:   page,
			PageSize:     size,
			TotalEntries: 1,
			TotalPages:   1,
		},
		Projects: []*projecthubpb.Project{
			{
				Metadata: &projecthubpb.Project_Metadata{
					Id:        "project-local",
					Name:      "Example Project",
					OrgId:     "org-local",
					OwnerId:   "user-local",
					CreatedAt: timestamppb.New(time.Unix(1_700_000_000, 0)),
				},
				Spec: &projecthubpb.Project_Spec{
					Repository: &projecthubpb.Project_Spec_Repository{
						Url:           "https://github.com/example/project",
						DefaultBranch: "main",
						PipelineFile:  ".semaphore/semaphore.yml",
					},
				},
			},
		},
	}, nil
}

// NewProjectDescribeResponse creates a minimal project describe response for tests.
func NewProjectDescribeResponse(orgID, projectID string, repo *projecthubpb.Project_Spec_Repository) *projecthubpb.DescribeResponse {
	if repo == nil {
		repo = &projecthubpb.Project_Spec_Repository{}
	}
	return &projecthubpb.DescribeResponse{
		Metadata: &projecthubpb.ResponseMeta{
			Status: &projecthubpb.ResponseMeta_Status{Code: projecthubpb.ResponseMeta_OK},
		},
		Project: &projecthubpb.Project{
			Metadata: &projecthubpb.Project_Metadata{Id: projectID, OrgId: orgID},
			Spec:     &projecthubpb.Project_Spec{Repository: repo},
		},
	}
}

// NewRBACStub returns an RBAC stub with optional default permissions.
func NewRBACStub(perms ...string) *RBACStub {
	copied := append([]string(nil), perms...)
	return &RBACStub{Permissions: copied}
}

// RBACStub records authorization checks and returns configurable results.
type RBACStub struct {
	rbacpb.RBACClient

	Permissions      []string
	PerProject       map[string][]string
	PerOrg           map[string][]string
	Err              error
	ErrorForProject  map[string]error
	ErrorForOrg      map[string]error
	LastRequests     []*rbacpb.ListUserPermissionsRequest
	AccessibleOrgIDs []string
}

func (s *RBACStub) ListUserPermissions(ctx context.Context, in *rbacpb.ListUserPermissionsRequest, opts ...grpc.CallOption) (*rbacpb.ListUserPermissionsResponse, error) {
	reqCopy := &rbacpb.ListUserPermissionsRequest{
		UserId:    in.GetUserId(),
		OrgId:     in.GetOrgId(),
		ProjectId: in.GetProjectId(),
	}
	s.LastRequests = append(s.LastRequests, reqCopy)

	if s.Err != nil {
		return nil, s.Err
	}

	projectKey := normalizeKey(in.GetProjectId())
	orgKey := normalizeKey(in.GetOrgId())

	if projectKey != "" {
		if err := s.ErrorForProject[projectKey]; err != nil {
			return nil, err
		}
	} else if orgKey != "" {
		if err := s.ErrorForOrg[orgKey]; err != nil {
			return nil, err
		}
	}

	perms := s.Permissions
	if projectKey != "" {
		if override, ok := s.PerProject[projectKey]; ok {
			perms = override
		}
	} else if orgKey != "" {
		if override, ok := s.PerOrg[orgKey]; ok {
			perms = override
		}
	}
	if perms == nil {
		perms = []string{}
	}

	return &rbacpb.ListUserPermissionsResponse{
		UserId:      in.GetUserId(),
		OrgId:       in.GetOrgId(),
		ProjectId:   in.GetProjectId(),
		Permissions: append([]string(nil), perms...),
	}, nil
}

func normalizeKey(value string) string {
	return strings.ToLower(strings.TrimSpace(value))
}

func (s *RBACStub) ListAccessibleOrgs(ctx context.Context, in *rbacpb.ListAccessibleOrgsRequest, opts ...grpc.CallOption) (*rbacpb.ListAccessibleOrgsResponse, error) {
	ids := s.AccessibleOrgIDs
	if len(ids) == 0 {
		ids = []string{"org-local"}
	}
	return &rbacpb.ListAccessibleOrgsResponse{OrgIds: append([]string(nil), ids...)}, nil
}

// UserClientStub captures user lookups and returns configurable responses.
type UserClientStub struct {
	userpb.UserServiceClient

	Response    *userpb.User
	Err         error
	LastRequest *userpb.DescribeByRepositoryProviderRequest
}

func (u *UserClientStub) DescribeByRepositoryProvider(ctx context.Context, in *userpb.DescribeByRepositoryProviderRequest, opts ...grpc.CallOption) (*userpb.User, error) {
	u.LastRequest = in
	if u.Err != nil {
		return nil, u.Err
	}
	if u.Response != nil {
		return u.Response, nil
	}
	login := "stub-user"
	if in != nil && in.GetProvider() != nil {
		candidate := strings.TrimSpace(in.GetProvider().GetLogin())
		if candidate != "" {
			login = candidate
		}
	}
	return &userpb.User{Id: fmt.Sprintf("user-%s", login)}, nil
}
