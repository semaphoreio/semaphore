package artifacts

import (
	"context"
	"fmt"
	"net/http"
	"strings"
	"testing"
	"time"

	"github.com/mark3labs/mcp-go/mcp"
	artifacthubpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/artifacthub"
	workflowpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/plumber_w_f.workflow"
	projecthubpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/projecthub"
	rbacpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/rbac"
	responsepb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/response_status"
	jobpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/server_farm.job"
	statuspb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/status"
	support "github.com/semaphoreio/semaphore/mcp_server/test/support"

	code "google.golang.org/genproto/googleapis/rpc/code"
	"google.golang.org/grpc"
)

const (
	testOrgID          = "11111111-1111-1111-1111-111111111111"
	testOtherOrgID     = "22222222-2222-2222-2222-222222222222"
	testProjectID      = "33333333-3333-3333-3333-333333333333"
	testOtherProjectID = "44444444-4444-4444-4444-444444444444"
	testJobID          = "55555555-5555-5555-5555-555555555555"
	testWorkflowID     = "66666666-6666-6666-6666-666666666666"
	testUserID         = "77777777-7777-7777-7777-777777777777"
	testArtifactStore  = "88888888-8888-8888-8888-888888888888"
)

func TestArtifactsListSuccessJobScope(t *testing.T) {
	artifactClient := &artifacthubClientStub{
		listResp: &artifacthubpb.ListPathResponse{
			Items: []*artifacthubpb.ListItem{
				{Name: fmt.Sprintf("artifacts/jobs/%s/agent", testJobID), IsDirectory: true, Size: 0},
				{Name: fmt.Sprintf("artifacts/jobs/%s/agent/job_logs.txt.gz", testJobID), IsDirectory: false, Size: 123},
			},
		},
	}

	rbac := support.NewRBACStub(artifactsViewPermission)
	provider := &support.MockProvider{
		Timeout:           time.Second,
		ArtifacthubClient: artifactClient,
		JobClient:         &jobClientStub{orgID: testOrgID, projectID: testProjectID},
		ProjectClient: &support.ProjectClientStub{
			Response: newProjectDescribeResponse(testOrgID, testProjectID, testArtifactStore),
		},
		RBACClient: rbac,
	}

	req := callRequest(map[string]any{
		"organization_id": testOrgID,
		"scope":           scopeJobs,
		"scope_id":        testJobID,
		"limit":           200,
	}, true)

	res, err := listHandler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("handler error: %v", err)
	}

	if res == nil || res.IsError {
		t.Fatalf("expected successful response, got: %#v", res)
	}

	result, ok := res.StructuredContent.(artifactListResult)
	if !ok {
		t.Fatalf("unexpected structured content type: %T", res.StructuredContent)
	}

	if result.ProjectID != testProjectID {
		t.Fatalf("expected project_id %s, got %s", testProjectID, result.ProjectID)
	}
	if len(result.Artifacts) != 2 {
		t.Fatalf("expected 2 artifacts, got %d", len(result.Artifacts))
	}
	if result.Artifacts[0].Path != "agent" {
		t.Fatalf("expected first relative path to be 'agent', got %s", result.Artifacts[0].Path)
	}
	if artifactClient.lastList == nil {
		t.Fatalf("expected ListPath request to be recorded")
	}
	if artifactClient.lastList.GetArtifactId() != testArtifactStore {
		t.Fatalf("expected artifact_id %s, got %s", testArtifactStore, artifactClient.lastList.GetArtifactId())
	}
	expectedListPath := fmt.Sprintf("artifacts/jobs/%s/", testJobID)
	if artifactClient.lastList.GetPath() != expectedListPath {
		t.Fatalf("expected list path %s, got %s", expectedListPath, artifactClient.lastList.GetPath())
	}
	if len(rbac.LastRequests) != 1 {
		t.Fatalf("expected 1 RBAC request, got %d", len(rbac.LastRequests))
	}
	if got := rbac.LastRequests[0].GetProjectId(); got != testProjectID {
		t.Fatalf("expected RBAC project %s, got %s", testProjectID, got)
	}
}

func TestArtifactsListSuccessWorkflowScopeWithoutProjectID(t *testing.T) {
	artifactClient := &artifacthubClientStub{
		listResp: &artifacthubpb.ListPathResponse{
			Items: []*artifacthubpb.ListItem{
				{Name: fmt.Sprintf("artifacts/workflows/%s/debug", testWorkflowID), IsDirectory: true, Size: 0},
			},
		},
	}
	workflowClient := &support.WorkflowClientStub{
		DescribeResp: &workflowpb.DescribeResponse{
			Status: &statuspb.Status{Code: code.Code_OK},
			Workflow: &workflowpb.WorkflowDetails{
				WfId:           testWorkflowID,
				OrganizationId: testOrgID,
				ProjectId:      testProjectID,
			},
		},
	}
	rbac := support.NewRBACStub(artifactsViewPermission)
	provider := &support.MockProvider{
		Timeout:           time.Second,
		WorkflowClient:    workflowClient,
		ArtifacthubClient: artifactClient,
		ProjectClient: &support.ProjectClientStub{
			Response: newProjectDescribeResponse(testOrgID, testProjectID, testArtifactStore),
		},
		RBACClient: rbac,
	}

	req := callRequest(map[string]any{
		"organization_id": testOrgID,
		"scope":           scopeWorkflows,
		"scope_id":        testWorkflowID,
	}, true)

	res, err := listHandler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("handler error: %v", err)
	}
	if res == nil || res.IsError {
		t.Fatalf("expected successful response, got: %#v", res)
	}

	result, ok := res.StructuredContent.(artifactListResult)
	if !ok {
		t.Fatalf("unexpected structured content type: %T", res.StructuredContent)
	}
	if result.ProjectID != testProjectID {
		t.Fatalf("expected project_id %s, got %s", testProjectID, result.ProjectID)
	}
	if workflowClient.LastDescribe == nil || workflowClient.LastDescribe.GetWfId() != testWorkflowID {
		t.Fatalf("expected workflow describe request for %s", testWorkflowID)
	}
}

func TestArtifactsListSuccessProjectScopeWithoutProjectID(t *testing.T) {
	artifactClient := &artifacthubClientStub{
		listResp: &artifacthubpb.ListPathResponse{
			Items: []*artifacthubpb.ListItem{
				{Name: fmt.Sprintf("artifacts/projects/%s/releases", testProjectID), IsDirectory: true, Size: 0},
			},
		},
	}
	rbac := support.NewRBACStub(artifactsViewPermission)
	provider := &support.MockProvider{
		Timeout:           time.Second,
		ArtifacthubClient: artifactClient,
		ProjectClient: &support.ProjectClientStub{
			Response: newProjectDescribeResponse(testOrgID, testProjectID, testArtifactStore),
		},
		RBACClient: rbac,
	}

	req := callRequest(map[string]any{
		"organization_id": testOrgID,
		"scope":           scopeProjects,
		"scope_id":        testProjectID,
	}, true)

	res, err := listHandler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("handler error: %v", err)
	}
	if res == nil || res.IsError {
		t.Fatalf("expected successful response, got: %#v", res)
	}

	result, ok := res.StructuredContent.(artifactListResult)
	if !ok {
		t.Fatalf("unexpected structured content type: %T", res.StructuredContent)
	}
	if result.ProjectID != testProjectID {
		t.Fatalf("expected project_id %s, got %s", testProjectID, result.ProjectID)
	}
	if len(rbac.LastRequests) != 1 {
		t.Fatalf("expected 1 RBAC request, got %d", len(rbac.LastRequests))
	}
	if got := rbac.LastRequests[0].GetProjectId(); got != testProjectID {
		t.Fatalf("expected RBAC project %s, got %s", testProjectID, got)
	}
}

func TestArtifactsListProjectIDMismatchReturnsScopeError(t *testing.T) {
	rbac := support.NewRBACStub(artifactsViewPermission)
	provider := &support.MockProvider{
		Timeout:    time.Second,
		JobClient:  &jobClientStub{orgID: testOrgID, projectID: testProjectID},
		RBACClient: rbac,
	}

	req := callRequest(map[string]any{
		"organization_id": testOrgID,
		"scope":           scopeJobs,
		"scope_id":        testJobID,
		"project_id":      testOtherProjectID,
	}, true)

	res, err := listHandler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("handler error: %v", err)
	}

	msg := requireErrorText(t, res)
	if !strings.Contains(msg, "outside the authorized project scope") {
		t.Fatalf("expected project scope mismatch error, got %q", msg)
	}
	if len(rbac.LastRequests) != 0 {
		t.Fatalf("expected no RBAC request on project mismatch, got %d", len(rbac.LastRequests))
	}
}

func TestArtifactsListWorkflowScopeProjectMismatchRejected(t *testing.T) {
	rbac := support.NewRBACStub(artifactsViewPermission)
	workflowClient := &support.WorkflowClientStub{
		DescribeResp: &workflowpb.DescribeResponse{
			Status: &statuspb.Status{Code: code.Code_OK},
			Workflow: &workflowpb.WorkflowDetails{
				WfId:           testWorkflowID,
				OrganizationId: testOrgID,
				ProjectId:      testProjectID,
			},
		},
	}
	provider := &support.MockProvider{
		Timeout:        time.Second,
		WorkflowClient: workflowClient,
		RBACClient:     rbac,
	}

	req := callRequest(map[string]any{
		"organization_id": testOrgID,
		"scope":           scopeWorkflows,
		"scope_id":        testWorkflowID,
		"project_id":      testOtherProjectID,
	}, true)

	res, err := listHandler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("handler error: %v", err)
	}

	msg := requireErrorText(t, res)
	if !strings.Contains(msg, "outside the authorized project scope") {
		t.Fatalf("expected project scope mismatch error, got %q", msg)
	}
	if len(rbac.LastRequests) != 0 {
		t.Fatalf("expected no RBAC request on scope mismatch, got %d", len(rbac.LastRequests))
	}
}

func TestArtifactsListProjectScopeProjectMismatchRejected(t *testing.T) {
	rbac := support.NewRBACStub(artifactsViewPermission)
	provider := &support.MockProvider{
		Timeout:    time.Second,
		RBACClient: rbac,
	}

	req := callRequest(map[string]any{
		"organization_id": testOrgID,
		"scope":           scopeProjects,
		"scope_id":        testProjectID,
		"project_id":      testOtherProjectID,
	}, true)

	res, err := listHandler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("handler error: %v", err)
	}

	msg := requireErrorText(t, res)
	if !strings.Contains(msg, "outside the authorized project scope") {
		t.Fatalf("expected project scope mismatch error, got %q", msg)
	}
	if len(rbac.LastRequests) != 0 {
		t.Fatalf("expected no RBAC request on scope mismatch, got %d", len(rbac.LastRequests))
	}
}

func TestArtifactsListOrgMismatchReturnsScopeError(t *testing.T) {
	rbac := support.NewRBACStub(artifactsViewPermission)
	provider := &support.MockProvider{
		Timeout:    time.Second,
		JobClient:  &jobClientStub{orgID: testOtherOrgID, projectID: testProjectID},
		RBACClient: rbac,
	}

	req := callRequest(map[string]any{
		"organization_id": testOrgID,
		"scope":           scopeJobs,
		"scope_id":        testJobID,
	}, true)

	res, err := listHandler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("handler error: %v", err)
	}

	msg := requireErrorText(t, res)
	if !strings.Contains(msg, "outside the authorized organization scope") {
		t.Fatalf("expected organization scope mismatch error, got %q", msg)
	}
	if len(rbac.LastRequests) != 0 {
		t.Fatalf("expected no RBAC request on org mismatch, got %d", len(rbac.LastRequests))
	}
}

func TestArtifactsListInvalidScopeRejected(t *testing.T) {
	req := callRequest(map[string]any{
		"organization_id": testOrgID,
		"scope":           "invalid",
		"scope_id":        testJobID,
	}, true)

	res, err := listHandler(&support.MockProvider{Timeout: time.Second})(context.Background(), req)
	if err != nil {
		t.Fatalf("handler error: %v", err)
	}

	msg := requireErrorText(t, res)
	if !strings.Contains(msg, "scope must be one of: projects, workflows, jobs") {
		t.Fatalf("expected invalid scope error, got %q", msg)
	}
}

func TestArtifactsListInvalidRBACPermissions(t *testing.T) {
	rbac := support.NewRBACStub("project.view")
	provider := &support.MockProvider{
		Timeout:   time.Second,
		JobClient: &jobClientStub{orgID: testOrgID, projectID: testProjectID},
		ProjectClient: &support.ProjectClientStub{
			Response: newProjectDescribeResponse(testOrgID, testProjectID, testArtifactStore),
		},
		ArtifacthubClient: &artifacthubClientStub{},
		RBACClient:        rbac,
	}

	req := callRequest(map[string]any{
		"organization_id": testOrgID,
		"scope":           scopeJobs,
		"scope_id":        testJobID,
	}, true)

	res, err := listHandler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("handler error: %v", err)
	}

	msg := requireErrorText(t, res)
	if !strings.Contains(msg, "Permission denied while accessing project") {
		t.Fatalf("expected permission denied error, got %q", msg)
	}
}

func TestArtifactsListInvalidRBACPermissionsWorkflowScope(t *testing.T) {
	workflowClient := &support.WorkflowClientStub{
		DescribeResp: &workflowpb.DescribeResponse{
			Status: &statuspb.Status{Code: code.Code_OK},
			Workflow: &workflowpb.WorkflowDetails{
				WfId:           testWorkflowID,
				OrganizationId: testOrgID,
				ProjectId:      testProjectID,
			},
		},
	}
	projectClient := &support.ProjectClientStub{
		Response: newProjectDescribeResponse(testOrgID, testProjectID, testArtifactStore),
	}
	artifactClient := &artifacthubClientStub{}
	rbac := support.NewRBACStub("project.view")
	provider := &support.MockProvider{
		Timeout:           time.Second,
		WorkflowClient:    workflowClient,
		ProjectClient:     projectClient,
		ArtifacthubClient: artifactClient,
		RBACClient:        rbac,
	}

	req := callRequest(map[string]any{
		"organization_id": testOrgID,
		"scope":           scopeWorkflows,
		"scope_id":        testWorkflowID,
	}, true)

	res, err := listHandler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("handler error: %v", err)
	}

	msg := requireErrorText(t, res)
	if !strings.Contains(msg, "Permission denied while accessing project") {
		t.Fatalf("expected permission denied error, got %q", msg)
	}
	if workflowClient.LastDescribe == nil {
		t.Fatalf("expected workflow describe to resolve project context")
	}
	if len(rbac.LastRequests) != 1 {
		t.Fatalf("expected 1 RBAC request, got %d", len(rbac.LastRequests))
	}
	if got := rbac.LastRequests[0].GetProjectId(); got != testProjectID {
		t.Fatalf("expected RBAC project %s, got %s", testProjectID, got)
	}
	if projectClient.LastDescribe != nil {
		t.Fatalf("expected project describe not to be called on RBAC deny")
	}
	if artifactClient.lastList != nil {
		t.Fatalf("expected artifacthub list not to be called on RBAC deny")
	}
}

func TestArtifactsSignedURLSuccessWorkflowScope(t *testing.T) {
	artifactClient := &artifacthubClientStub{
		signedURL: "https://example.com/signed",
	}
	workflowClient := &support.WorkflowClientStub{
		DescribeResp: &workflowpb.DescribeResponse{
			Status: &statuspb.Status{Code: code.Code_OK},
			Workflow: &workflowpb.WorkflowDetails{
				WfId:           testWorkflowID,
				OrganizationId: testOrgID,
				ProjectId:      testProjectID,
			},
		},
	}
	rbac := support.NewRBACStub(artifactsViewPermission)
	provider := &support.MockProvider{
		Timeout:           time.Second,
		WorkflowClient:    workflowClient,
		ArtifacthubClient: artifactClient,
		ProjectClient: &support.ProjectClientStub{
			Response: newProjectDescribeResponse(testOrgID, testProjectID, testArtifactStore),
		},
		RBACClient: rbac,
	}

	req := callRequest(map[string]any{
		"organization_id": testOrgID,
		"scope":           scopeWorkflows,
		"scope_id":        testWorkflowID,
		"path":            "debug/workflow_logs.txt",
		"method":          "head",
	}, true)

	res, err := signedURLHandler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("handler error: %v", err)
	}

	if res == nil || res.IsError {
		t.Fatalf("expected successful response, got: %#v", res)
	}

	result, ok := res.StructuredContent.(signedURLResult)
	if !ok {
		t.Fatalf("unexpected structured content type: %T", res.StructuredContent)
	}
	if result.Method != "HEAD" {
		t.Fatalf("expected method HEAD, got %s", result.Method)
	}
	if result.URL != "https://example.com/signed" {
		t.Fatalf("unexpected signed URL: %s", result.URL)
	}
	if artifactClient.lastSigned == nil {
		t.Fatalf("expected GetSignedURL request to be recorded")
	}
	expectedPath := fmt.Sprintf("artifacts/workflows/%s/debug/workflow_logs.txt", testWorkflowID)
	if artifactClient.lastSigned.GetPath() != expectedPath {
		t.Fatalf("expected signed path %s, got %s", expectedPath, artifactClient.lastSigned.GetPath())
	}
	if artifactClient.lastSigned.GetMethod() != "HEAD" {
		t.Fatalf("expected signed method HEAD, got %s", artifactClient.lastSigned.GetMethod())
	}
	if workflowClient.LastDescribe == nil || workflowClient.LastDescribe.GetWfId() != testWorkflowID {
		t.Fatalf("expected workflow describe request for %s", testWorkflowID)
	}
}

func TestArtifactsSignedURLSuccessJobScopeWithoutProjectID(t *testing.T) {
	artifactClient := &artifacthubClientStub{
		signedURL: "https://example.com/job-signed",
	}
	rbac := support.NewRBACStub(artifactsViewPermission)
	provider := &support.MockProvider{
		Timeout:           time.Second,
		JobClient:         &jobClientStub{orgID: testOrgID, projectID: testProjectID},
		ArtifacthubClient: artifactClient,
		ProjectClient: &support.ProjectClientStub{
			Response: newProjectDescribeResponse(testOrgID, testProjectID, testArtifactStore),
		},
		RBACClient: rbac,
	}

	req := callRequest(map[string]any{
		"organization_id": testOrgID,
		"scope":           scopeJobs,
		"scope_id":        testJobID,
		"path":            "agent/job_logs.txt.gz",
	}, true)

	res, err := signedURLHandler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("handler error: %v", err)
	}
	if res == nil || res.IsError {
		t.Fatalf("expected successful response, got: %#v", res)
	}

	result, ok := res.StructuredContent.(signedURLResult)
	if !ok {
		t.Fatalf("unexpected structured content type: %T", res.StructuredContent)
	}
	if result.ProjectID != testProjectID {
		t.Fatalf("expected project_id %s, got %s", testProjectID, result.ProjectID)
	}
	if artifactClient.lastSigned == nil {
		t.Fatalf("expected GetSignedURL request to be recorded")
	}
}

func TestArtifactsSignedURLSuccessProjectScopeWithoutProjectID(t *testing.T) {
	artifactClient := &artifacthubClientStub{
		signedURL: "https://example.com/project-signed",
	}
	rbac := support.NewRBACStub(artifactsViewPermission)
	provider := &support.MockProvider{
		Timeout:           time.Second,
		ArtifacthubClient: artifactClient,
		ProjectClient: &support.ProjectClientStub{
			Response: newProjectDescribeResponse(testOrgID, testProjectID, testArtifactStore),
		},
		RBACClient: rbac,
	}

	req := callRequest(map[string]any{
		"organization_id": testOrgID,
		"scope":           scopeProjects,
		"scope_id":        testProjectID,
		"path":            "releases/build.tar.gz",
	}, true)

	res, err := signedURLHandler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("handler error: %v", err)
	}
	if res == nil || res.IsError {
		t.Fatalf("expected successful response, got: %#v", res)
	}

	result, ok := res.StructuredContent.(signedURLResult)
	if !ok {
		t.Fatalf("unexpected structured content type: %T", res.StructuredContent)
	}
	if result.ProjectID != testProjectID {
		t.Fatalf("expected project_id %s, got %s", testProjectID, result.ProjectID)
	}
}

func TestArtifactsSignedURLPermissionDenied(t *testing.T) {
	provider := &support.MockProvider{
		Timeout:   time.Second,
		JobClient: &jobClientStub{orgID: testOrgID, projectID: testProjectID},
		ProjectClient: &support.ProjectClientStub{
			Response: newProjectDescribeResponse(testOrgID, testProjectID, testArtifactStore),
		},
		ArtifacthubClient: &artifacthubClientStub{signedURL: "https://example.com/ignored"},
		RBACClient:        support.NewRBACStub(), // no permissions
	}

	req := callRequest(map[string]any{
		"organization_id": testOrgID,
		"scope":           scopeJobs,
		"scope_id":        testJobID,
		"path":            "agent/job_logs.txt.gz",
	}, true)

	res, err := signedURLHandler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("handler error: %v", err)
	}

	msg := requireErrorText(t, res)
	if !strings.Contains(msg, "Permission denied while accessing project") {
		t.Fatalf("expected permission denied error, got %q", msg)
	}
}

func TestArtifactsSignedURLInvalidRBACPermissions(t *testing.T) {
	provider := &support.MockProvider{
		Timeout:   time.Second,
		JobClient: &jobClientStub{orgID: testOrgID, projectID: testProjectID},
		ProjectClient: &support.ProjectClientStub{
			Response: newProjectDescribeResponse(testOrgID, testProjectID, testArtifactStore),
		},
		ArtifacthubClient: &artifacthubClientStub{signedURL: "https://example.com/ignored"},
		RBACClient:        support.NewRBACStub("project.view"),
	}

	req := callRequest(map[string]any{
		"organization_id": testOrgID,
		"scope":           scopeJobs,
		"scope_id":        testJobID,
		"path":            "agent/job_logs.txt.gz",
	}, true)

	res, err := signedURLHandler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("handler error: %v", err)
	}

	msg := requireErrorText(t, res)
	if !strings.Contains(msg, "Permission denied while accessing project") {
		t.Fatalf("expected permission denied error, got %q", msg)
	}
}

func TestArtifactsSignedURLInvalidRBACPermissionsWorkflowScope(t *testing.T) {
	workflowClient := &support.WorkflowClientStub{
		DescribeResp: &workflowpb.DescribeResponse{
			Status: &statuspb.Status{Code: code.Code_OK},
			Workflow: &workflowpb.WorkflowDetails{
				WfId:           testWorkflowID,
				OrganizationId: testOrgID,
				ProjectId:      testProjectID,
			},
		},
	}
	projectClient := &support.ProjectClientStub{
		Response: newProjectDescribeResponse(testOrgID, testProjectID, testArtifactStore),
	}
	artifactClient := &artifacthubClientStub{signedURL: "https://example.com/ignored"}
	rbac := support.NewRBACStub("project.view")
	provider := &support.MockProvider{
		Timeout:           time.Second,
		WorkflowClient:    workflowClient,
		ProjectClient:     projectClient,
		ArtifacthubClient: artifactClient,
		RBACClient:        rbac,
	}

	req := callRequest(map[string]any{
		"organization_id": testOrgID,
		"scope":           scopeWorkflows,
		"scope_id":        testWorkflowID,
		"path":            "debug/workflow_logs.txt",
	}, true)

	res, err := signedURLHandler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("handler error: %v", err)
	}

	msg := requireErrorText(t, res)
	if !strings.Contains(msg, "Permission denied while accessing project") {
		t.Fatalf("expected permission denied error, got %q", msg)
	}
	if workflowClient.LastDescribe == nil {
		t.Fatalf("expected workflow describe to resolve project context")
	}
	if len(rbac.LastRequests) != 1 {
		t.Fatalf("expected 1 RBAC request, got %d", len(rbac.LastRequests))
	}
	if got := rbac.LastRequests[0].GetProjectId(); got != testProjectID {
		t.Fatalf("expected RBAC project %s, got %s", testProjectID, got)
	}
	if projectClient.LastDescribe != nil {
		t.Fatalf("expected project describe not to be called on RBAC deny")
	}
	if artifactClient.lastSigned != nil {
		t.Fatalf("expected signed URL RPC not to be called on RBAC deny")
	}
}

func TestArtifactsSignedURLProjectScopeMismatchRejected(t *testing.T) {
	rbac := support.NewRBACStub(artifactsViewPermission)
	provider := &support.MockProvider{
		Timeout:    time.Second,
		RBACClient: rbac,
	}

	req := callRequest(map[string]any{
		"organization_id": testOrgID,
		"scope":           scopeProjects,
		"scope_id":        testProjectID,
		"project_id":      testOtherProjectID,
		"path":            "releases/build.tar.gz",
	}, true)

	res, err := signedURLHandler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("handler error: %v", err)
	}

	msg := requireErrorText(t, res)
	if !strings.Contains(msg, "outside the authorized project scope") {
		t.Fatalf("expected project scope mismatch error, got %q", msg)
	}
	if len(rbac.LastRequests) != 0 {
		t.Fatalf("expected no RBAC request on scope mismatch, got %d", len(rbac.LastRequests))
	}
}

func TestArtifactsSignedURLWorkflowScopeProjectMismatchRejected(t *testing.T) {
	rbac := support.NewRBACStub(artifactsViewPermission)
	workflowClient := &support.WorkflowClientStub{
		DescribeResp: &workflowpb.DescribeResponse{
			Status: &statuspb.Status{Code: code.Code_OK},
			Workflow: &workflowpb.WorkflowDetails{
				WfId:           testWorkflowID,
				OrganizationId: testOrgID,
				ProjectId:      testProjectID,
			},
		},
	}
	provider := &support.MockProvider{
		Timeout:        time.Second,
		WorkflowClient: workflowClient,
		RBACClient:     rbac,
	}

	req := callRequest(map[string]any{
		"organization_id": testOrgID,
		"scope":           scopeWorkflows,
		"scope_id":        testWorkflowID,
		"project_id":      testOtherProjectID,
		"path":            "debug/workflow_logs.txt",
	}, true)

	res, err := signedURLHandler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("handler error: %v", err)
	}

	msg := requireErrorText(t, res)
	if !strings.Contains(msg, "outside the authorized project scope") {
		t.Fatalf("expected project scope mismatch error, got %q", msg)
	}
	if len(rbac.LastRequests) != 0 {
		t.Fatalf("expected no RBAC request on scope mismatch, got %d", len(rbac.LastRequests))
	}
}

func TestArtifactsSignedURLJobScopeProjectMismatchRejected(t *testing.T) {
	rbac := support.NewRBACStub(artifactsViewPermission)
	provider := &support.MockProvider{
		Timeout:    time.Second,
		JobClient:  &jobClientStub{orgID: testOrgID, projectID: testProjectID},
		RBACClient: rbac,
	}

	req := callRequest(map[string]any{
		"organization_id": testOrgID,
		"scope":           scopeJobs,
		"scope_id":        testJobID,
		"project_id":      testOtherProjectID,
		"path":            "agent/job_logs.txt.gz",
	}, true)

	res, err := signedURLHandler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("handler error: %v", err)
	}

	msg := requireErrorText(t, res)
	if !strings.Contains(msg, "outside the authorized project scope") {
		t.Fatalf("expected project scope mismatch error, got %q", msg)
	}
	if len(rbac.LastRequests) != 0 {
		t.Fatalf("expected no RBAC request on scope mismatch, got %d", len(rbac.LastRequests))
	}
}

func TestArtifactsSignedURLRejectsPathTraversal(t *testing.T) {
	req := callRequest(map[string]any{
		"organization_id": testOrgID,
		"scope":           scopeProjects,
		"scope_id":        testProjectID,
		"path":            "../secret.txt",
	}, true)

	res, err := signedURLHandler(&support.MockProvider{Timeout: time.Second})(context.Background(), req)
	if err != nil {
		t.Fatalf("handler error: %v", err)
	}

	msg := requireErrorText(t, res)
	if !strings.Contains(msg, "path traversal is not allowed") {
		t.Fatalf("expected path traversal error, got %q", msg)
	}
}

func TestArtifactsListMissingUserHeaderRejected(t *testing.T) {
	req := callRequest(map[string]any{
		"organization_id": testOrgID,
		"scope":           scopeProjects,
		"scope_id":        testProjectID,
	}, false)

	res, err := listHandler(&support.MockProvider{Timeout: time.Second})(context.Background(), req)
	if err != nil {
		t.Fatalf("handler error: %v", err)
	}

	msg := requireErrorText(t, res)
	if !strings.Contains(msg, "X-Semaphore-User-ID") {
		t.Fatalf("expected missing header error, got %q", msg)
	}
}

func callRequest(args map[string]any, includeUser bool) mcp.CallToolRequest {
	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: args}}
	if includeUser {
		header := http.Header{}
		header.Set("X-Semaphore-User-ID", testUserID)
		req.Header = header
	}
	return req
}

func requireErrorText(t *testing.T, res *mcp.CallToolResult) string {
	t.Helper()
	if res == nil {
		t.Fatalf("expected tool result, got nil")
	}
	if !res.IsError {
		t.Fatalf("expected error result, got success: %#v", res)
	}
	for _, content := range res.Content {
		if text, ok := content.(mcp.TextContent); ok {
			msg := strings.TrimSpace(text.Text)
			if msg != "" {
				return msg
			}
		}
	}
	t.Fatalf("expected text error content, got %#v", res.Content)
	return ""
}

func newProjectDescribeResponse(orgID, projectID, artifactStoreID string) *projecthubpb.DescribeResponse {
	return &projecthubpb.DescribeResponse{
		Metadata: &projecthubpb.ResponseMeta{
			Status: &projecthubpb.ResponseMeta_Status{Code: projecthubpb.ResponseMeta_OK},
		},
		Project: &projecthubpb.Project{
			Metadata: &projecthubpb.Project_Metadata{
				Id:    projectID,
				OrgId: orgID,
			},
			Spec: &projecthubpb.Project_Spec{
				ArtifactStoreId: artifactStoreID,
			},
		},
	}
}

type artifacthubClientStub struct {
	artifacthubpb.ArtifactServiceClient

	listResp   *artifacthubpb.ListPathResponse
	listErr    error
	lastList   *artifacthubpb.ListPathRequest
	signedURL  string
	signedErr  error
	lastSigned *artifacthubpb.GetSignedURLRequest
}

func (s *artifacthubClientStub) ListPath(ctx context.Context, in *artifacthubpb.ListPathRequest, opts ...grpc.CallOption) (*artifacthubpb.ListPathResponse, error) {
	s.lastList = in
	if s.listErr != nil {
		return nil, s.listErr
	}
	if s.listResp != nil {
		return s.listResp, nil
	}
	return &artifacthubpb.ListPathResponse{}, nil
}

func (s *artifacthubClientStub) GetSignedURL(ctx context.Context, in *artifacthubpb.GetSignedURLRequest, opts ...grpc.CallOption) (*artifacthubpb.GetSignedURLResponse, error) {
	s.lastSigned = in
	if s.signedErr != nil {
		return nil, s.signedErr
	}
	return &artifacthubpb.GetSignedURLResponse{Url: s.signedURL}, nil
}

type jobClientStub struct {
	jobpb.JobServiceClient

	orgID        string
	projectID    string
	describeErr  error
	lastDescribe *jobpb.DescribeRequest
}

func (s *jobClientStub) Describe(ctx context.Context, in *jobpb.DescribeRequest, opts ...grpc.CallOption) (*jobpb.DescribeResponse, error) {
	s.lastDescribe = in
	if s.describeErr != nil {
		return nil, s.describeErr
	}
	return &jobpb.DescribeResponse{
		Status: &responsepb.ResponseStatus{Code: responsepb.ResponseStatus_OK},
		Job: &jobpb.Job{
			Id:             in.GetJobId(),
			OrganizationId: s.orgID,
			ProjectId:      s.projectID,
		},
	}, nil
}

var _ rbacpb.RBACClient = (*support.RBACStub)(nil)
