package projects

import (
	"context"
	"net/http"
	"testing"
	"time"

	"github.com/mark3labs/mcp-go/mcp"
	rbacpb "github.com/semaphoreio/semaphore/bootstrapper/pkg/protos/rbac"
	projecthubpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/projecthub"
	repoipb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/repository_integrator"

	"github.com/semaphoreio/semaphore/mcp_server/pkg/internalapi"

	"google.golang.org/grpc"
	"google.golang.org/protobuf/types/known/timestamppb"
)

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

	provider := &internalapi.MockProvider{
		ProjectClient: stub,
		RBACClient:    &allowRBACStub{},
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

	provider := &internalapi.MockProvider{
		ProjectClient: stub,
		RBACClient:    &allowRBACStub{},
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

type projectClientStub struct {
	projecthubpb.ProjectServiceClient
	keysetResponses map[string]*projecthubpb.ListKeysetResponse
	responses       map[int32]*projecthubpb.ListResponse
	calls           []string
	pageCalls       []int32
	err             error
}

type allowRBACStub struct {
	rbacpb.RBACClient
}

func (a *allowRBACStub) ListUserPermissions(ctx context.Context, in *rbacpb.ListUserPermissionsRequest, opts ...grpc.CallOption) (*rbacpb.ListUserPermissionsResponse, error) {
	return &rbacpb.ListUserPermissionsResponse{
		UserId:      in.GetUserId(),
		OrgId:       in.GetOrgId(),
		ProjectId:   in.GetProjectId(),
		Permissions: []string{"organization.view", "project.view"},
	}, nil
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
