package testresults

import (
	"context"
	"net/http"
	"strings"
	"testing"
	"time"

	"github.com/mark3labs/mcp-go/mcp"
	"google.golang.org/grpc"

	"github.com/semaphoreio/semaphore/mcp_server/pkg/feature"
	artifacthubpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/artifacthub"
	pipelinepb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/plumber.pipeline"
	projecthubpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/projecthub"
	rbacpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/rbac"
	responsepb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/response_status"
	jobpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/server_farm.job"
	support "github.com/semaphoreio/semaphore/mcp_server/test/support"
)

const (
	testOrgID          = "11111111-1111-1111-1111-111111111111"
	testOrgIDOther     = "22222222-2222-2222-2222-222222222222"
	testProjectID      = "33333333-3333-3333-3333-333333333333"
	testProjectIDOther = "44444444-4444-4444-4444-444444444444"
	testPipelineID     = "55555555-5555-5555-5555-555555555555"
	testWorkflowID     = "66666666-6666-6666-6666-666666666666"
	testJobID          = "77777777-7777-7777-7777-777777777777"
	testUserID         = "88888888-8888-8888-8888-888888888888"
	testStoreID        = "99999999-9999-9999-9999-999999999999"
)

func TestSignedURL_PublicProject_AllowsGuest(t *testing.T) {
	provider := &support.MockProvider{
		Timeout: time.Second,
		FeaturesService: support.FeatureClientStub{
			State: feature.Enabled,
		},
		ArtifacthubClient: &artifacthubStub{url: "https://example.com/public.json", listItems: []string{testPipelineID + "-mcp-summary.json"}},
		ProjectClient:     &projectStub{orgID: testOrgID, projectID: testProjectID, public: true, artifactStoreID: testStoreID},
		PipelineClient:    &pipelineStub{orgID: testOrgID, projectID: testProjectID, workflowID: testWorkflowID},
		RBACClient:        &rbacStub{perms: []string{"project.view"}},
	}

	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"scope":       "pipeline",
		"pipeline_id": testPipelineID,
		"workflow_id": testWorkflowID,
	}}}
	// No user header (guest)

	res, err := handler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("handler error: %v", err)
	}
	if res == nil || res.StructuredContent == nil {
		t.Fatalf("expected structured content")
	}
	content, ok := res.StructuredContent.(map[string]string)
	if !ok {
		t.Fatalf("unexpected content type: %T", res.StructuredContent)
	}
	if content["artifactUrl"] != "https://example.com/public.json" {
		t.Fatalf("unexpected url: %+v", content)
	}
}

func TestSignedURL_PrivateProject_MissingUserHeader(t *testing.T) {
	provider := &support.MockProvider{
		Timeout:           time.Second,
		FeaturesService:   support.FeatureClientStub{State: feature.Enabled},
		ArtifacthubClient: &artifacthubStub{url: "https://example.com/private.json", listItems: []string{testPipelineID + "-mcp-summary.json"}},
		ProjectClient:     &projectStub{orgID: testOrgID, projectID: testProjectID, public: false, artifactStoreID: testStoreID},
		PipelineClient:    &pipelineStub{orgID: testOrgID, projectID: testProjectID, workflowID: testWorkflowID},
		RBACClient:        &rbacStub{perms: []string{"project.view"}},
	}

	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"scope":       "pipeline",
		"pipeline_id": testPipelineID,
		"workflow_id": testWorkflowID,
	}}}

	res, err := handler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("handler error: %v", err)
	}
	msg := requireErrorText(t, res)
	if msg == "" {
		t.Fatalf("expected error")
	}
	if !contains(msg, "X-Semaphore-User-ID") {
		t.Fatalf("expected missing header error, got: %s", msg)
	}
}

func TestSignedURL_PrivateProject_WithPermission(t *testing.T) {
	provider := &support.MockProvider{
		Timeout:           time.Second,
		FeaturesService:   support.FeatureClientStub{State: feature.Enabled},
		ArtifacthubClient: &artifacthubStub{url: "https://example.com/private.json", listItems: []string{testPipelineID + "-mcp-summary.json"}},
		ProjectClient:     &projectStub{orgID: testOrgID, projectID: testProjectID, public: false, artifactStoreID: testStoreID},
		PipelineClient:    &pipelineStub{orgID: testOrgID, projectID: testProjectID, workflowID: testWorkflowID},
		RBACClient:        &rbacStub{perms: []string{"project.view"}},
	}

	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"scope":       "pipeline",
		"pipeline_id": testPipelineID,
		"workflow_id": testWorkflowID,
	}}}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", testUserID)
	req.Header = header

	res, err := handler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("handler error: %v", err)
	}
	content, ok := res.StructuredContent.(map[string]string)
	if !ok {
		t.Fatalf("unexpected content type: %T", res.StructuredContent)
	}
	if content["artifactUrl"] != "https://example.com/private.json" {
		t.Fatalf("unexpected url: %+v", content)
	}
	if content["compression"] != "none" {
		t.Fatalf("expected compression=none, got: %s", content["compression"])
	}
}

func TestDescribeProject_PassesMetadata(t *testing.T) {
	projectClient := &projectStub{orgID: testOrgID, projectID: testProjectID, public: false, artifactStoreID: testStoreID}

	provider := &support.MockProvider{
		Timeout:           time.Second,
		FeaturesService:   support.FeatureClientStub{State: feature.Enabled},
		ArtifacthubClient: &artifacthubStub{url: "https://example.com/private.json", listItems: []string{testPipelineID + "-mcp-summary.json"}},
		ProjectClient:     projectClient,
		PipelineClient:    &pipelineStub{orgID: testOrgID, projectID: testProjectID, workflowID: testWorkflowID},
		RBACClient:        &rbacStub{perms: []string{"project.view"}},
	}

	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"scope":       "pipeline",
		"pipeline_id": testPipelineID,
		"workflow_id": testWorkflowID,
	}}}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", testUserID)
	req.Header = header

	res, err := handler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("handler error: %v", err)
	}
	if res == nil || res.StructuredContent == nil {
		t.Fatalf("expected structured content on success")
	}
	if projectClient.lastDescribe == nil {
		t.Fatalf("expected project describe to be called")
	}
	meta := projectClient.lastDescribe.GetMetadata()
	if meta == nil {
		t.Fatalf("expected metadata to be set on project describe request")
	}
	if meta.GetOrgId() != testOrgID {
		t.Fatalf("expected org_id %s, got: %s", testOrgID, meta.GetOrgId())
	}
	if meta.GetUserId() != testUserID {
		t.Fatalf("expected user_id %s, got: %s", testUserID, meta.GetUserId())
	}
	if strings.TrimSpace(meta.GetReqId()) == "" {
		t.Fatalf("expected req_id to be populated")
	}
}

func TestSignedURL_JobScope_WithPermission(t *testing.T) {
	provider := &support.MockProvider{
		Timeout:           time.Second,
		FeaturesService:   support.FeatureClientStub{State: feature.Enabled},
		ArtifacthubClient: &artifacthubStub{url: "https://example.com/job-results.json", listItems: []string{"mcp-summary.json"}},
		ProjectClient:     &projectStub{orgID: testOrgID, projectID: testProjectID, public: false, artifactStoreID: testStoreID},
		JobClient:         &jobStub{orgID: testOrgID, projectID: testProjectID},
		RBACClient:        &rbacStub{perms: []string{"project.view"}},
	}

	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"scope":  "job",
		"job_id": testJobID,
	}}}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", testUserID)
	req.Header = header

	res, err := handler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("handler error: %v", err)
	}
	content, ok := res.StructuredContent.(map[string]string)
	if !ok {
		t.Fatalf("unexpected content type: %T", res.StructuredContent)
	}
	if content["artifactUrl"] != "https://example.com/job-results.json" {
		t.Fatalf("unexpected url: %+v", content)
	}
	if content["scope"] != "job" {
		t.Fatalf("expected scope=job, got: %s", content["scope"])
	}
	expectedPath := "artifacts/jobs/" + testJobID + "/test-results/mcp-summary.json"
	if content["path"] != expectedPath {
		t.Fatalf("expected path=%s, got: %s", expectedPath, content["path"])
	}
	if content["compression"] != "none" {
		t.Fatalf("expected compression=none, got: %s", content["compression"])
	}
}

func TestSignedURL_JobScope_PublicProject_AllowsGuest(t *testing.T) {
	provider := &support.MockProvider{
		Timeout:           time.Second,
		FeaturesService:   support.FeatureClientStub{State: feature.Enabled},
		ArtifacthubClient: &artifacthubStub{url: "https://example.com/public-job.json", listItems: []string{"mcp-summary.json"}},
		ProjectClient:     &projectStub{orgID: testOrgID, projectID: testProjectID, public: true, artifactStoreID: testStoreID},
		JobClient:         &jobStub{orgID: testOrgID, projectID: testProjectID},
		RBACClient:        &rbacStub{perms: []string{"project.view"}},
	}

	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"scope":  "job",
		"job_id": testJobID,
	}}}
	// No user header (guest)

	res, err := handler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("handler error: %v", err)
	}
	content, ok := res.StructuredContent.(map[string]string)
	if !ok {
		t.Fatalf("unexpected content type: %T", res.StructuredContent)
	}
	if content["artifactUrl"] != "https://example.com/public-job.json" {
		t.Fatalf("unexpected url: %+v", content)
	}
	if content["compression"] != "none" {
		t.Fatalf("expected compression=none, got: %s", content["compression"])
	}
}

func TestSignedURL_JobScope_MissingJobID(t *testing.T) {
	provider := &support.MockProvider{
		Timeout:           time.Second,
		FeaturesService:   support.FeatureClientStub{State: feature.Enabled},
		ArtifacthubClient: &artifacthubStub{url: "https://example.com/job.json"},
		ProjectClient:     &projectStub{orgID: testOrgID, projectID: testProjectID, public: true, artifactStoreID: testStoreID},
		JobClient:         &jobStub{orgID: testOrgID, projectID: testProjectID},
		RBACClient:        &rbacStub{perms: []string{"project.view"}},
	}

	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"scope": "job",
		// job_id is missing
	}}}

	res, err := handler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("handler error: %v", err)
	}
	msg := requireErrorText(t, res)
	if msg == "" {
		t.Fatalf("expected error for missing job_id")
	}
	if !contains(msg, "job_id is required") {
		t.Fatalf("expected job_id required error, got: %s", msg)
	}
}

func TestSignedURL_JobScope_OrgMismatch(t *testing.T) {
	provider := &support.MockProvider{
		Timeout:           time.Second,
		FeaturesService:   support.FeatureClientStub{State: feature.Enabled},
		ArtifacthubClient: &artifacthubStub{url: "https://example.com/job.json"},
		ProjectClient:     &projectStub{orgID: testOrgID, projectID: testProjectID, public: true, artifactStoreID: testStoreID},
		JobClient:         &jobStub{orgID: testOrgIDOther, projectID: testProjectID}, // Job belongs to different org
		RBACClient:        &rbacStub{perms: []string{"project.view"}},
	}

	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"scope":  "job",
		"job_id": testJobID,
	}}}

	res, err := handler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("handler error: %v", err)
	}
	msg := requireErrorText(t, res)
	if msg == "" {
		t.Fatalf("expected error for org mismatch")
	}
	if !contains(msg, "organization") {
		t.Fatalf("expected organization mismatch error, got: %s", msg)
	}
}

func TestSignedURL_JobScope_ProjectMismatch(t *testing.T) {
	provider := &support.MockProvider{
		Timeout:           time.Second,
		FeaturesService:   support.FeatureClientStub{State: feature.Enabled},
		ArtifacthubClient: &artifacthubStub{url: "https://example.com/job.json"},
		ProjectClient:     &projectStub{orgID: testOrgID, projectID: testProjectID, public: true, artifactStoreID: testStoreID},
		JobClient:         &jobStub{orgID: testOrgID, projectID: testProjectIDOther}, // Job belongs to different project
		RBACClient:        &rbacStub{perms: []string{"project.view"}},
	}

	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"scope":  "job",
		"job_id": testJobID,
	}}}

	res, err := handler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("handler error: %v", err)
	}
	msg := requireErrorText(t, res)
	if msg == "" {
		t.Fatalf("expected error for project mismatch")
	}
	if !contains(msg, "project") {
		t.Fatalf("expected project mismatch error, got: %s", msg)
	}
}

func TestSignedURL_JobScope_FallsBackToJunit(t *testing.T) {
	provider := &support.MockProvider{
		Timeout:           time.Second,
		FeaturesService:   support.FeatureClientStub{State: feature.Enabled},
		ArtifacthubClient: &artifacthubStub{url: "https://example.com/job-junit.xml", listItems: []string{"junit.xml"}},
		ProjectClient:     &projectStub{orgID: testOrgID, projectID: testProjectID, public: true, artifactStoreID: testStoreID},
		JobClient:         &jobStub{orgID: testOrgID, projectID: testProjectID},
		RBACClient:        &rbacStub{perms: []string{"project.view"}},
	}

	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"scope":  "job",
		"job_id": testJobID,
	}}}

	res, err := handler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("handler error: %v", err)
	}
	content, ok := res.StructuredContent.(map[string]string)
	if !ok {
		t.Fatalf("unexpected content type: %T", res.StructuredContent)
	}
	if content["path"] != "artifacts/jobs/"+testJobID+"/test-results/junit.xml" {
		t.Fatalf("expected junit path, got: %s", content["path"])
	}
	if content["content_type"] != "application/xml" {
		t.Fatalf("expected xml content type, got: %s", content["content_type"])
	}
}

func TestSignedURL_PipelineScope_FallsBackToSummary(t *testing.T) {
	provider := &support.MockProvider{
		Timeout:           time.Second,
		FeaturesService:   support.FeatureClientStub{State: feature.Enabled},
		ArtifacthubClient: &artifacthubStub{url: "https://example.com/pipeline-summary.json", listItems: []string{testPipelineID + "-summary.json"}},
		ProjectClient:     &projectStub{orgID: testOrgID, projectID: testProjectID, public: true, artifactStoreID: testStoreID},
		PipelineClient:    &pipelineStub{orgID: testOrgID, projectID: testProjectID, workflowID: testWorkflowID},
		RBACClient:        &rbacStub{perms: []string{"project.view"}},
	}

	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"scope":       "pipeline",
		"pipeline_id": testPipelineID,
		"workflow_id": testWorkflowID,
	}}}

	res, err := handler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("handler error: %v", err)
	}
	content, ok := res.StructuredContent.(map[string]string)
	if !ok {
		t.Fatalf("unexpected content type: %T", res.StructuredContent)
	}
	if content["path"] != "artifacts/workflows/"+testWorkflowID+"/test-results/"+testPipelineID+"-summary.json" {
		t.Fatalf("expected summary path, got: %s", content["path"])
	}
	if content["compression"] != "gzip" {
		t.Fatalf("expected compression=gzip for summary fallback, got: %s", content["compression"])
	}
}

func TestSignedURL_ErrorsWhenNoArtifactsFound(t *testing.T) {
	provider := &support.MockProvider{
		Timeout:           time.Second,
		FeaturesService:   support.FeatureClientStub{State: feature.Enabled},
		ArtifacthubClient: &artifacthubStub{url: "https://example.com/missing.json", listItems: []string{}},
		ProjectClient:     &projectStub{orgID: testOrgID, projectID: testProjectID, public: true, artifactStoreID: testStoreID},
		PipelineClient:    &pipelineStub{orgID: testOrgID, projectID: testProjectID, workflowID: testWorkflowID},
		RBACClient:        &rbacStub{perms: []string{"project.view"}},
	}

	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"scope":       "pipeline",
		"pipeline_id": testPipelineID,
		"workflow_id": testWorkflowID,
	}}}

	res, err := handler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("handler error: %v", err)
	}

	msg := requireErrorText(t, res)
	if !contains(msg, "no test result artifacts") {
		t.Fatalf("expected missing artifacts error, got: %s", msg)
	}
}

// --- stubs ---

type artifacthubStub struct {
	artifacthubpb.ArtifactServiceClient
	url       string
	listErr   error
	listItems []string
}

func (a *artifacthubStub) GetSignedURL(ctx context.Context, req *artifacthubpb.GetSignedURLRequest, opts ...grpc.CallOption) (*artifacthubpb.GetSignedURLResponse, error) {
	return &artifacthubpb.GetSignedURLResponse{Url: a.url}, nil
}

func (a *artifacthubStub) ListPath(ctx context.Context, req *artifacthubpb.ListPathRequest, opts ...grpc.CallOption) (*artifacthubpb.ListPathResponse, error) {
	if a.listErr != nil {
		return nil, a.listErr
	}

	resp := &artifacthubpb.ListPathResponse{}
	for _, name := range a.listItems {
		resp.Items = append(resp.Items, &artifacthubpb.ListItem{Name: name})
	}
	return resp, nil
}

type projectStub struct {
	projecthubpb.ProjectServiceClient
	orgID           string
	projectID       string
	public          bool
	artifactStoreID string
	lastDescribe    *projecthubpb.DescribeRequest
}

func (p *projectStub) Describe(ctx context.Context, req *projecthubpb.DescribeRequest, opts ...grpc.CallOption) (*projecthubpb.DescribeResponse, error) {
	p.lastDescribe = req

	visibility := projecthubpb.Project_Spec_PRIVATE
	if p.public {
		visibility = projecthubpb.Project_Spec_PUBLIC
	}
	return &projecthubpb.DescribeResponse{
		Metadata: &projecthubpb.ResponseMeta{
			Status: &projecthubpb.ResponseMeta_Status{Code: projecthubpb.ResponseMeta_OK},
		},
		Project: &projecthubpb.Project{
			Metadata: &projecthubpb.Project_Metadata{
				Id:    p.projectID,
				OrgId: p.orgID,
			},
			Spec: &projecthubpb.Project_Spec{
				Visibility:      visibility,
				Public:          p.public,
				ArtifactStoreId: p.artifactStoreID,
			},
		},
	}, nil
}

type pipelineStub struct {
	pipelinepb.PipelineServiceClient
	orgID      string
	projectID  string
	workflowID string
}

func (p *pipelineStub) Describe(ctx context.Context, req *pipelinepb.DescribeRequest, opts ...grpc.CallOption) (*pipelinepb.DescribeResponse, error) {
	return &pipelinepb.DescribeResponse{
		ResponseStatus: &pipelinepb.ResponseStatus{Code: pipelinepb.ResponseStatus_OK},
		Pipeline: &pipelinepb.Pipeline{
			PplId:          req.GetPplId(),
			WfId:           p.workflowID,
			ProjectId:      p.projectID,
			OrganizationId: p.orgID,
		},
	}, nil
}

type jobStub struct {
	jobpb.JobServiceClient
	orgID     string
	projectID string
}

func (j *jobStub) Describe(ctx context.Context, req *jobpb.DescribeRequest, opts ...grpc.CallOption) (*jobpb.DescribeResponse, error) {
	return &jobpb.DescribeResponse{
		Status: &responsepb.ResponseStatus{Code: responsepb.ResponseStatus_OK},
		Job: &jobpb.Job{
			Id:             req.GetJobId(),
			OrganizationId: j.orgID,
			ProjectId:      j.projectID,
		},
	}, nil
}

type rbacStub struct {
	rbacpb.RBACClient
	perms []string
}

func (r *rbacStub) ListUserPermissions(ctx context.Context, req *rbacpb.ListUserPermissionsRequest, opts ...grpc.CallOption) (*rbacpb.ListUserPermissionsResponse, error) {
	return &rbacpb.ListUserPermissionsResponse{Permissions: r.perms}, nil
}

// --- helpers ---

func requireErrorText(t *testing.T, res *mcp.CallToolResult) string {
	t.Helper()
	if res == nil {
		t.Fatalf("nil result")
	}
	if !res.IsError {
		return ""
	}
	if len(res.Content) == 0 {
		return ""
	}
	text, ok := res.Content[0].(mcp.TextContent)
	if !ok {
		return ""
	}
	return text.Text
}

func contains(s, substr string) bool {
	return strings.Contains(strings.ToLower(s), strings.ToLower(substr))
}
