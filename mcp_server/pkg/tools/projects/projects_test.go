package projects

import (
	"context"
	"net/http"
	"strings"
	"testing"
	"time"

	"github.com/mark3labs/mcp-go/mcp"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/feature"
	projecthubpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/projecthub"
	rbacpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/rbac"
	repoipb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/repository_integrator"
	support "github.com/semaphoreio/semaphore/mcp_server/test/support"

	"google.golang.org/grpc"
	"google.golang.org/protobuf/types/known/timestamppb"
)

func TestListProjects_FeatureFlagDisabled(t *testing.T) {
	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"organization_id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
	}}}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", "99999999-aaaa-bbbb-cccc-dddddddddddd")
	req.Header = header

	provider := &support.MockProvider{
		FeaturesService: support.FeatureClientStub{State: feature.Hidden},
		Timeout:         time.Second,
		ProjectClient:   &projectClientStub{},
		RBACClient:      newRBACStub("organization.view", "project.view"),
	}

	res, err := listHandler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	msg := requireErrorText(t, res)
	if !strings.Contains(strings.ToLower(msg), "disabled") {
		t.Fatalf("expected disabled feature error, got %q", msg)
	}
}

func TestSearchProjects_FeatureFlagDisabled(t *testing.T) {
	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"organization_id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
		"query":           "search",
	}}}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", "99999999-aaaa-bbbb-cccc-dddddddddddd")
	req.Header = header

	provider := &support.MockProvider{
		FeaturesService: support.FeatureClientStub{State: feature.Hidden},
		Timeout:         time.Second,
		ProjectClient:   &projectClientStub{},
		RBACClient:      newRBACStub("organization.view", "project.view"),
	}

	res, err := searchHandler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	msg := requireErrorText(t, res)
	if !strings.Contains(strings.ToLower(msg), "disabled") {
		t.Fatalf("expected disabled feature error, got %q", msg)
	}
}

func TestListProjectsSummary(t *testing.T) {
	orgID := "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
	stub := &projectClientStub{
		keysetResponses: map[string]*projecthubpb.ListKeysetResponse{
			"": {
				Metadata:      okMetadata(),
				NextPageToken: "next-page-token",
				Projects: []*projecthubpb.Project{
					makeProject("proj-1", "API Service", orgID, "https://github.com/example/api", "main"),
				},
			},
		},
	}

	provider := &support.MockProvider{
		ProjectClient: stub,
		RBACClient:    newRBACStub("organization.view", "project.view"),
	}

	handler := listHandler(provider)
	req := mcp.CallToolRequest{
		Params: mcp.CallToolParams{
			Arguments: map[string]any{
				"organization_id": orgID,
				"cursor":          "",
				"limit":           10,
			},
		},
	}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", "99999999-aaaa-bbbb-cccc-dddddddddddd")
	req.Header = header

	res, err := handler(context.Background(), req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if res.IsError {
		t.Fatalf("expected success, got error result: %+v", res)
	}

	out, ok := res.StructuredContent.(listResult)
	if !ok {
		t.Fatalf("unexpected structured content type: %T", res.StructuredContent)
	}
	if len(out.Projects) != 1 {
		t.Fatalf("expected 1 project, got %d", len(out.Projects))
	}
	if out.NextCursor != "next-page-token" {
		t.Fatalf("expected nextCursor=next-page-token, got %q", out.NextCursor)
	}
	if out.Projects[0].Repository.URL != "https://github.com/example/api" {
		t.Fatalf("unexpected repository url: %s", out.Projects[0].Repository.URL)
	}
}

func TestListProjectsPermissionDenied(t *testing.T) {
	orgID := "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
	stub := &projectClientStub{}
	rbac := newRBACStub()

	provider := &support.MockProvider{
		ProjectClient: stub,
		RBACClient:    rbac,
	}

	handler := listHandler(provider)
	req := mcp.CallToolRequest{
		Params: mcp.CallToolParams{
			Arguments: map[string]any{
				"organization_id": orgID,
			},
		},
	}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", "99999999-aaaa-bbbb-cccc-dddddddddddd")
	req.Header = header

	res, err := handler(context.Background(), req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	msg := requireErrorText(t, res)
	if !strings.Contains(msg, `Permission denied while accessing organization`) {
		t.Fatalf("expected permission denied message, got %q", msg)
	}
	if len(stub.calls) != 0 {
		t.Fatalf("expected ProjectHub not to be called, got %v", stub.calls)
	}
	if len(rbac.lastRequests) != 1 {
		t.Fatalf("expected one RBAC request, got %d", len(rbac.lastRequests))
	}
}

func TestListProjectsRBACUnavailable(t *testing.T) {
	orgID := "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
	stub := &projectClientStub{}

	provider := &support.MockProvider{
		ProjectClient: stub,
	}

	handler := listHandler(provider)
	req := mcp.CallToolRequest{
		Params: mcp.CallToolParams{
			Arguments: map[string]any{
				"organization_id": orgID,
			},
		},
	}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", "99999999-aaaa-bbbb-cccc-dddddddddddd")
	req.Header = header

	res, err := handler(context.Background(), req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	msg := requireErrorText(t, res)
	if !strings.Contains(msg, "Authorization service is not configured") {
		t.Fatalf("expected RBAC unavailable message, got %q", msg)
	}
	if len(stub.calls) != 0 {
		t.Fatalf("expected ProjectHub not to be called, got %v", stub.calls)
	}
}

func TestListProjectsScopeMismatch(t *testing.T) {
	orgID := "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
	stub := &projectClientStub{
		keysetResponses: map[string]*projecthubpb.ListKeysetResponse{
			"": {
				Metadata: okMetadata(),
				Projects: []*projecthubpb.Project{
					makeProject("proj-1", "API Service", "bbbbbbbb-cccc-dddd-eeee-ffffffffffff", "https://github.com/example/api", "main"),
				},
			},
		},
	}
	rbac := newRBACStub("organization.view")

	provider := &support.MockProvider{
		ProjectClient: stub,
		RBACClient:    rbac,
	}

	handler := listHandler(provider)
	req := mcp.CallToolRequest{
		Params: mcp.CallToolParams{
			Arguments: map[string]any{
				"organization_id": orgID,
			},
		},
	}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", "99999999-aaaa-bbbb-cccc-dddddddddddd")
	req.Header = header

	res, err := handler(context.Background(), req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	msg := requireErrorText(t, res)
	if !strings.Contains(msg, "outside the authorized organization scope") {
		t.Fatalf("expected scope mismatch message, got %q", msg)
	}
	if len(rbac.lastRequests) != 1 {
		t.Fatalf("expected one RBAC request, got %d", len(rbac.lastRequests))
	}
}

func TestSearchProjectsMatches(t *testing.T) {
	orgID := "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
	stub := &projectClientStub{
		responses: map[int32]*projecthubpb.ListResponse{
			1: {
				Metadata: okMetadata(),
				Pagination: &projecthubpb.PaginationResponse{
					PageNumber:   1,
					PageSize:     searchPageSize,
					TotalEntries: 2,
					TotalPages:   2,
				},
				Projects: []*projecthubpb.Project{
					makeProject("proj-1", "API Service", orgID, "https://github.com/example/api", "main"),
					makeProject("proj-2", "Marketing Site", orgID, "https://github.com/example/marketing", "main"),
				},
			},
			2: {
				Metadata: okMetadata(),
				Pagination: &projecthubpb.PaginationResponse{
					PageNumber:   2,
					PageSize:     searchPageSize,
					TotalEntries: 2,
					TotalPages:   2,
				},
				Projects: []*projecthubpb.Project{
					makeProject("proj-3", "Payments API", orgID, "https://github.com/example/payments", "release"),
				},
			},
		},
	}

	provider := &support.MockProvider{
		ProjectClient: stub,
		RBACClient:    newRBACStub("organization.view", "project.view"),
	}

	handler := searchHandler(provider)
	req := mcp.CallToolRequest{
		Params: mcp.CallToolParams{
			Arguments: map[string]any{
				"organization_id": orgID,
				"query":           "api",
				"limit":           2,
				"max_pages":       2,
				"mode":            "detailed",
			},
		},
	}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", "99999999-aaaa-bbbb-cccc-dddddddddddd")
	req.Header = header

	res, err := handler(context.Background(), req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if res.IsError {
		t.Fatalf("expected success, got error result: %+v", res)
	}

	out, ok := res.StructuredContent.(searchResult)
	if !ok {
		t.Fatalf("unexpected structured content type: %T", res.StructuredContent)
	}

	if len(out.Projects) != 2 {
		t.Fatalf("expected 2 results, got %d", len(out.Projects))
	}

	if out.Projects[0].ID != "proj-1" {
		t.Fatalf("expected proj-1 first, got %s", out.Projects[0].ID)
	}

	if out.Projects[0].Details == nil {
		t.Fatalf("expected detailed mode to include details")
	}

	if out.TotalMatches < len(out.Projects) {
		t.Fatalf("expected total matches to be >= returned projects")
	}

	if stub.pageCalls[0] != 1 || stub.pageCalls[1] != 2 {
		t.Fatalf("expected pages 1 and 2 to be fetched, got %v", stub.pageCalls)
	}
}

func TestSearchProjectsPermissionDenied(t *testing.T) {
	orgID := "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
	stub := &projectClientStub{}
	rbac := newRBACStub()

	provider := &support.MockProvider{
		ProjectClient: stub,
		RBACClient:    rbac,
	}

	handler := searchHandler(provider)
	req := mcp.CallToolRequest{
		Params: mcp.CallToolParams{
			Arguments: map[string]any{
				"organization_id": orgID,
				"query":           "api",
			},
		},
	}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", "99999999-aaaa-bbbb-cccc-dddddddddddd")
	req.Header = header

	res, err := handler(context.Background(), req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	msg := requireErrorText(t, res)
	if !strings.Contains(msg, `Permission denied while accessing organization`) {
		t.Fatalf("expected permission denied message, got %q", msg)
	}
	if len(stub.pageCalls) != 0 {
		t.Fatalf("expected no pagination calls, got %v", stub.pageCalls)
	}
	if len(rbac.lastRequests) != 1 {
		t.Fatalf("expected one RBAC call, got %d", len(rbac.lastRequests))
	}
}

func TestSearchProjectsScopeMismatch(t *testing.T) {
	orgID := "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
	stub := &projectClientStub{
		responses: map[int32]*projecthubpb.ListResponse{
			1: {
				Metadata: okMetadata(),
				Pagination: &projecthubpb.PaginationResponse{
					PageNumber:   1,
					PageSize:     searchPageSize,
					TotalEntries: 1,
					TotalPages:   1,
				},
				Projects: []*projecthubpb.Project{
					makeProject("proj-1", "API Service", "bbbbbbbb-cccc-dddd-eeee-ffffffffffff", "https://github.com/example/api", "main"),
				},
			},
		},
	}
	rbac := newRBACStub("organization.view")

	provider := &support.MockProvider{
		ProjectClient: stub,
		RBACClient:    rbac,
	}

	handler := searchHandler(provider)
	req := mcp.CallToolRequest{
		Params: mcp.CallToolParams{
			Arguments: map[string]any{
				"organization_id": orgID,
				"query":           "api",
			},
		},
	}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", "99999999-aaaa-bbbb-cccc-dddddddddddd")
	req.Header = header

	res, err := handler(context.Background(), req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	msg := requireErrorText(t, res)
	if !strings.Contains(msg, "outside the authorized organization scope") {
		t.Fatalf("expected scope mismatch message, got %q", msg)
	}
}

type projectClientStub struct {
	projecthubpb.ProjectServiceClient
	keysetResponses map[string]*projecthubpb.ListKeysetResponse
	responses       map[int32]*projecthubpb.ListResponse
	calls           []string
	pageCalls       []int32
	err             error
}

func (p *projectClientStub) ListKeyset(ctx context.Context, in *projecthubpb.ListKeysetRequest, opts ...grpc.CallOption) (*projecthubpb.ListKeysetResponse, error) {
	cursor := in.GetPageToken()
	p.calls = append(p.calls, cursor)
	if p.err != nil {
		return nil, p.err
	}
	if resp, ok := p.keysetResponses[cursor]; ok {
		return resp, nil
	}
	return &projecthubpb.ListKeysetResponse{
		Metadata:      okMetadata(),
		NextPageToken: "",
		Projects:      []*projecthubpb.Project{},
	}, nil
}

func requireErrorText(t *testing.T, res *mcp.CallToolResult) string {
	t.Helper()
	if res == nil {
		t.Fatalf("expected tool result")
	}
	if !res.IsError {
		t.Fatalf("expected error result, got success")
	}
	if len(res.Content) == 0 {
		t.Fatalf("expected error content")
	}
	text, ok := res.Content[0].(mcp.TextContent)
	if !ok {
		t.Fatalf("expected text content, got %T", res.Content[0])
	}
	return text.Text
}

func newRBACStub(perms ...string) *rbacStub {
	copied := append([]string(nil), perms...)
	return &rbacStub{permissions: copied}
}

type rbacStub struct {
	rbacpb.RBACClient

	permissions     []string
	perProject      map[string][]string
	perOrg          map[string][]string
	err             error
	errorForProject map[string]error
	errorForOrg     map[string]error
	lastRequests    []*rbacpb.ListUserPermissionsRequest
}

func (s *rbacStub) ListUserPermissions(ctx context.Context, in *rbacpb.ListUserPermissionsRequest, opts ...grpc.CallOption) (*rbacpb.ListUserPermissionsResponse, error) {
	reqCopy := &rbacpb.ListUserPermissionsRequest{
		UserId:    in.GetUserId(),
		OrgId:     in.GetOrgId(),
		ProjectId: in.GetProjectId(),
	}
	s.lastRequests = append(s.lastRequests, reqCopy)

	if s.err != nil {
		return nil, s.err
	}

	projectKey := normalizeKey(in.GetProjectId())
	orgKey := normalizeKey(in.GetOrgId())

	if projectKey != "" {
		if err := s.errorForProject[projectKey]; err != nil {
			return nil, err
		}
	} else if orgKey != "" {
		if err := s.errorForOrg[orgKey]; err != nil {
			return nil, err
		}
	}

	perms := s.permissions
	if projectKey != "" {
		if override, ok := s.perProject[projectKey]; ok {
			perms = override
		}
	} else if orgKey != "" {
		if override, ok := s.perOrg[orgKey]; ok {
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

func (p *projectClientStub) List(ctx context.Context, in *projecthubpb.ListRequest, opts ...grpc.CallOption) (*projecthubpb.ListResponse, error) {
	page := in.GetPagination().GetPage()
	p.pageCalls = append(p.pageCalls, page)
	if p.err != nil {
		return nil, p.err
	}
	if resp, ok := p.responses[page]; ok {
		return resp, nil
	}
	return &projecthubpb.ListResponse{
		Metadata:   okMetadata(),
		Pagination: &projecthubpb.PaginationResponse{PageNumber: page, PageSize: in.GetPagination().GetPageSize()},
		Projects:   []*projecthubpb.Project{},
	}, nil
}

func okMetadata() *projecthubpb.ResponseMeta {
	return &projecthubpb.ResponseMeta{
		Status: &projecthubpb.ResponseMeta_Status{Code: projecthubpb.ResponseMeta_OK},
	}
}

func makeProject(id, name, orgID, repoURL, defaultBranch string) *projecthubpb.Project {
	return &projecthubpb.Project{
		Metadata: &projecthubpb.Project_Metadata{
			Id:        id,
			Name:      name,
			OrgId:     orgID,
			OwnerId:   "user-1",
			CreatedAt: timestamppb.New(time.Unix(1_700_000_000, 0)),
		},
		Spec: &projecthubpb.Project_Spec{
			Repository: &projecthubpb.Project_Spec_Repository{
				Url:             repoURL,
				DefaultBranch:   defaultBranch,
				IntegrationType: repoipb.IntegrationType_GITHUB_APP,
				PipelineFile:    ".semaphore/semaphore.yml",
			},
			Schedulers: []*projecthubpb.Project_Spec_Scheduler{},
			Tasks:      []*projecthubpb.Project_Spec_Task{},
		},
	}
}
