package artifacts

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strings"
	"testing"
	"time"

	"github.com/mark3labs/mcp-go/mcp"
	"github.com/mark3labs/mcp-go/server"
	auditlog "github.com/semaphoreio/semaphore/mcp_server/pkg/audit"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/feature"
	artifacthubpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/artifacthub"
	auditpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/audit"
	workflowpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/plumber_w_f.workflow"
	projecthubpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/projecthub"
	rbacpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/rbac"
	responsepb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/response_status"
	jobpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/server_farm.job"
	statuspb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/status"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/logging"
	support "github.com/semaphoreio/semaphore/mcp_server/test/support"

	code "google.golang.org/genproto/googleapis/rpc/code"
	"google.golang.org/grpc"
	grpccodes "google.golang.org/grpc/codes"
	grpcstatus "google.golang.org/grpc/status"
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

	rbac := support.NewRBACStub(artifactsRequiredPermissions...)
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
	if artifactClient.lastList.GetUnwrapDirectories() {
		t.Fatalf("expected unwrap_directories=false")
	}
	if len(rbac.LastRequests) != 1 {
		t.Fatalf("expected 1 RBAC request, got %d", len(rbac.LastRequests))
	}
	if got := rbac.LastRequests[0].GetProjectId(); got != testProjectID {
		t.Fatalf("expected RBAC project %s, got %s", testProjectID, got)
	}
}

func TestArtifactsListLogsStdoutAuditOperation(t *testing.T) {
	artifactClient := &artifacthubClientStub{
		listResp: &artifacthubpb.ListPathResponse{
			Items: []*artifacthubpb.ListItem{
				{Name: fmt.Sprintf("artifacts/jobs/%s/agent/job_logs.txt.gz", testJobID), IsDirectory: false, Size: 123},
			},
		},
	}

	provider := &support.MockProvider{
		Timeout:           time.Second,
		ArtifacthubClient: artifactClient,
		JobClient:         &jobClientStub{orgID: testOrgID, projectID: testProjectID},
		ProjectClient: &support.ProjectClientStub{
			Response: newProjectDescribeResponse(testOrgID, testProjectID, testArtifactStore),
		},
		RBACClient: support.NewRBACStub(artifactsRequiredPermissions...),
	}

	logs := captureLoggerOutput(t)

	req := callRequest(map[string]any{
		"organization_id": testOrgID,
		"scope":           scopeJobs,
		"scope_id":        testJobID,
		"path":            "agent",
	}, true)

	res, err := listHandler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("handler error: %v", err)
	}
	if res == nil || res.IsError {
		t.Fatalf("expected successful response, got: %#v", res)
	}

	expectedResourceName := fmt.Sprintf("artifacts/jobs/%s/agent", testJobID)
	output := logs.String()
	if !strings.Contains(output, "AuditLog") {
		t.Fatalf("expected stdout audit log, got %q", output)
	}
	if !strings.Contains(output, `"operation":"List"`) {
		t.Fatalf("expected stdout audit log to include List operation, got %q", output)
	}
	if !strings.Contains(output, testUserID) {
		t.Fatalf("expected stdout audit log to include user_id %s, got %q", testUserID, output)
	}
	if !strings.Contains(output, testOrgID) {
		t.Fatalf("expected stdout audit log to include org_id %s, got %q", testOrgID, output)
	}
	if !strings.Contains(output, expectedResourceName) {
		t.Fatalf("expected stdout audit log to include resource_name %s, got %q", expectedResourceName, output)
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
	rbac := support.NewRBACStub(artifactsRequiredPermissions...)
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
	if artifactClient.lastList == nil {
		t.Fatalf("expected ListPath request to be recorded")
	}
	if artifactClient.lastList.GetArtifactId() != testArtifactStore {
		t.Fatalf("expected artifact_id %s, got %s", testArtifactStore, artifactClient.lastList.GetArtifactId())
	}
}

func TestArtifactsListPreservesEncodedSpaceAndPlusInArtifactPaths(t *testing.T) {
	artifactClient := &artifacthubClientStub{
		listResp: &artifacthubpb.ListPathResponse{
			Items: []*artifacthubpb.ListItem{
				{Name: fmt.Sprintf("artifacts/projects/%s/reports/build log+v1%%23.txt", testProjectID), IsDirectory: false, Size: 11},
				{Name: fmt.Sprintf("artifacts/projects/%s/reports/report%%2ejson", testProjectID), IsDirectory: false, Size: 22},
			},
		},
	}
	provider := &support.MockProvider{
		Timeout:           time.Second,
		ArtifacthubClient: artifactClient,
		ProjectClient: &support.ProjectClientStub{
			Response: newProjectDescribeResponse(testOrgID, testProjectID, testArtifactStore),
		},
		RBACClient: support.NewRBACStub(artifactsRequiredPermissions...),
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
	if len(result.Artifacts) != 2 {
		t.Fatalf("expected 2 artifacts, got %d", len(result.Artifacts))
	}

	if result.Artifacts[0].Path != "reports/build log+v1%23.txt" {
		t.Fatalf("unexpected first artifact path: %q", result.Artifacts[0].Path)
	}
	if result.Artifacts[1].Path != "reports/report%2ejson" {
		t.Fatalf("unexpected second artifact path: %q", result.Artifacts[1].Path)
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
	rbac := support.NewRBACStub(artifactsRequiredPermissions...)
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
	if artifactClient.lastList == nil {
		t.Fatalf("expected ListPath request to be recorded")
	}
	if artifactClient.lastList.GetArtifactId() != testArtifactStore {
		t.Fatalf("expected artifact_id %s, got %s", testArtifactStore, artifactClient.lastList.GetArtifactId())
	}
}

func TestArtifactsListProjectIDMismatchReturnsScopeError(t *testing.T) {
	rbac := support.NewRBACStub(artifactsRequiredPermissions...)
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
	rbac := support.NewRBACStub(artifactsRequiredPermissions...)
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
	rbac := support.NewRBACStub(artifactsRequiredPermissions...)
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

func TestArtifactsListProjectScopeOrgMismatchRejectedBeforeRBAC(t *testing.T) {
	rbac := support.NewRBACStub(artifactsRequiredPermissions...)
	projectClient := &support.ProjectClientStub{
		Response: newProjectDescribeResponse(testOtherOrgID, testProjectID, testArtifactStore),
	}
	provider := &support.MockProvider{
		Timeout:       time.Second,
		ProjectClient: projectClient,
		RBACClient:    rbac,
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

	msg := requireErrorText(t, res)
	if !strings.Contains(msg, "outside the authorized organization scope") {
		t.Fatalf("expected organization scope mismatch error, got %q", msg)
	}
	if len(rbac.LastRequests) != 0 {
		t.Fatalf("expected no RBAC request on org mismatch, got %d", len(rbac.LastRequests))
	}
	if projectClient.LastDescribe == nil {
		t.Fatalf("expected project describe to run before RBAC")
	}
}

func TestArtifactsListOrgMismatchReturnsScopeError(t *testing.T) {
	rbac := support.NewRBACStub(artifactsRequiredPermissions...)
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
	rbac := support.NewRBACStub("organization.view")
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
	rbac := support.NewRBACStub("organization.view")
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

func TestArtifactsListProjectScopePermissionDenied(t *testing.T) {
	artifactClient := &artifacthubClientStub{}
	projectClient := &support.ProjectClientStub{
		Response: newProjectDescribeResponse(testOrgID, testProjectID, testArtifactStore),
	}
	rbac := support.NewRBACStub("organization.view")
	provider := &support.MockProvider{
		Timeout:           time.Second,
		ProjectClient:     projectClient,
		ArtifacthubClient: artifactClient,
		RBACClient:        rbac,
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

	msg := requireErrorText(t, res)
	if !strings.Contains(msg, "Permission denied while accessing project") {
		t.Fatalf("expected permission denied error, got %q", msg)
	}
	if projectClient.LastDescribe == nil {
		t.Fatalf("expected project describe to run before RBAC for project scope")
	}
	if len(rbac.LastRequests) != 1 {
		t.Fatalf("expected 1 RBAC request, got %d", len(rbac.LastRequests))
	}
	if got := rbac.LastRequests[0].GetProjectId(); got != testProjectID {
		t.Fatalf("expected RBAC project %s, got %s", testProjectID, got)
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
	rbac := support.NewRBACStub(artifactsRequiredPermissions...)
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
	if len(result.URLs) != 1 {
		t.Fatalf("expected 1 signed URL entry, got %d", len(result.URLs))
	}
	if result.URLs[0].URL != "https://example.com/signed" {
		t.Fatalf("unexpected signed URL: %s", result.URLs[0].URL)
	}
	if result.URLs[0].Method != "HEAD" {
		t.Fatalf("expected signed URL method HEAD, got %s", result.URLs[0].Method)
	}
	if artifactClient.lastSingleSigned == nil {
		t.Fatalf("expected GetSignedURL request to be recorded")
	}
	expectedPath := fmt.Sprintf("artifacts/workflows/%s/debug/workflow_logs.txt", testWorkflowID)
	if artifactClient.lastSingleSigned.GetPath() != expectedPath {
		t.Fatalf("expected signed path %s, got %s", expectedPath, artifactClient.lastSingleSigned.GetPath())
	}
	if artifactClient.lastSingleSigned.GetMethod() != "HEAD" {
		t.Fatalf("expected signed method HEAD, got %s", artifactClient.lastSingleSigned.GetMethod())
	}
	if artifactClient.lastSingleSigned.GetArtifactId() != testArtifactStore {
		t.Fatalf("expected artifact_id %s, got %s", testArtifactStore, artifactClient.lastSingleSigned.GetArtifactId())
	}
	if workflowClient.LastDescribe == nil || workflowClient.LastDescribe.GetWfId() != testWorkflowID {
		t.Fatalf("expected workflow describe request for %s", testWorkflowID)
	}
}

func TestArtifactsSignedURLSuccessJobScopeWithoutProjectID(t *testing.T) {
	artifactClient := &artifacthubClientStub{
		signedURL: "https://example.com/job-signed",
	}
	rbac := support.NewRBACStub(artifactsRequiredPermissions...)
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
		"path":            "agent/output.log",
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
	if artifactClient.lastSingleSigned == nil {
		t.Fatalf("expected GetSignedURL request to be recorded")
	}
	if artifactClient.lastSingleSigned.GetArtifactId() != testArtifactStore {
		t.Fatalf("expected artifact_id %s, got %s", testArtifactStore, artifactClient.lastSingleSigned.GetArtifactId())
	}
	if len(result.URLs) != 1 {
		t.Fatalf("expected single signed URL entry, got %d", len(result.URLs))
	}
}

func TestArtifactsSignedURLEmitsAuditEventWithFullResourcePath(t *testing.T) {
	artifactClient := &artifacthubClientStub{
		listRespByPath: map[string]*artifacthubpb.ListPathResponse{
			fmt.Sprintf("artifacts/jobs/%s/agent/", testJobID): {
				Items: []*artifacthubpb.ListItem{
					{
						Name:        fmt.Sprintf("artifacts/jobs/%s/agent/job_logs.txt", testJobID),
						IsDirectory: false,
						Size:        123,
					},
				},
			},
		},
		signedURL: "https://example.com/job-signed",
	}
	provider := &support.MockProvider{
		Timeout:           time.Second,
		JobClient:         &jobClientStub{orgID: testOrgID, projectID: testProjectID},
		ArtifacthubClient: artifactClient,
		ProjectClient: &support.ProjectClientStub{
			Response: newProjectDescribeResponse(testOrgID, testProjectID, testArtifactStore),
		},
		RBACClient: support.NewRBACStub(artifactsRequiredPermissions...),
		FeaturesService: support.FeatureClientStub{
			State: feature.Hidden,
			States: map[string]feature.State{
				"mcp_server_read_tools":      feature.Enabled,
				"mcp_server_artifacts_tools": feature.Enabled,
				"audit_logs":                 feature.Enabled,
			},
		},
	}

	publisher := &auditPublisherStub{}
	restore := auditlog.SetPublisherForTests(publisher)
	defer restore()

	req := callRequest(map[string]any{
		"organization_id": testOrgID,
		"scope":           scopeJobs,
		"scope_id":        testJobID,
		"path":            "agent/job_logs.txt.gz",
		"method":          "HEAD",
	}, true)

	res, err := signedURLHandler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("handler error: %v", err)
	}
	if res == nil || res.IsError {
		t.Fatalf("expected successful response, got: %#v", res)
	}

	if len(publisher.events) != 1 {
		t.Fatalf("expected one audit event, got %d", len(publisher.events))
	}

	event := publisher.events[0]
	if event.GetResource() != auditpb.Event_Artifact {
		t.Fatalf("expected Artifact resource, got %v", event.GetResource())
	}
	if event.GetOperation() != auditpb.Event_Download {
		t.Fatalf("expected Download operation, got %v", event.GetOperation())
	}
	if event.GetUserId() != testUserID {
		t.Fatalf("expected user_id %s, got %s", testUserID, event.GetUserId())
	}
	if event.GetOrgId() != testOrgID {
		t.Fatalf("expected org_id %s, got %s", testOrgID, event.GetOrgId())
	}
	expectedResourceName := fmt.Sprintf("artifacts/jobs/%s/agent/job_logs.txt", testJobID)
	if event.GetResourceName() != expectedResourceName {
		t.Fatalf("expected resource_name %s, got %s", expectedResourceName, event.GetResourceName())
	}
	if event.GetResourceId() != testJobID {
		t.Fatalf("expected resource_id %s, got %s", testJobID, event.GetResourceId())
	}

	if artifactClient.lastSingleSigned == nil {
		t.Fatalf("expected GetSignedURL request to be recorded")
	}
	expectedSignedURLPath := fmt.Sprintf("artifacts/jobs/%s/agent/job_logs.txt", testJobID)
	if artifactClient.lastSingleSigned.GetPath() != expectedSignedURLPath {
		t.Fatalf("expected resolved signed URL path %s, got %s", expectedSignedURLPath, artifactClient.lastSingleSigned.GetPath())
	}

	meta := map[string]string{}
	if err := json.Unmarshal([]byte(event.GetMetadata()), &meta); err != nil {
		t.Fatalf("failed to decode metadata JSON: %v", err)
	}
	if meta["source_kind"] != scopeJobs {
		t.Fatalf("expected source_kind %s, got %s", scopeJobs, meta["source_kind"])
	}
	if meta["source_id"] != testJobID {
		t.Fatalf("expected source_id %s, got %s", testJobID, meta["source_id"])
	}
	if meta["project_id"] != testProjectID {
		t.Fatalf("expected project_id %s, got %s", testProjectID, meta["project_id"])
	}
	if meta["request_method"] != "HEAD" {
		t.Fatalf("expected request_method HEAD, got %s", meta["request_method"])
	}
}

func TestArtifactsSignedURLFailsWhenAuditPublishFails(t *testing.T) {
	artifactClient := &artifacthubClientStub{
		signedURL: "https://example.com/job-signed",
	}
	provider := &support.MockProvider{
		Timeout:           time.Second,
		JobClient:         &jobClientStub{orgID: testOrgID, projectID: testProjectID},
		ArtifacthubClient: artifactClient,
		ProjectClient: &support.ProjectClientStub{
			Response: newProjectDescribeResponse(testOrgID, testProjectID, testArtifactStore),
		},
		RBACClient: support.NewRBACStub(artifactsRequiredPermissions...),
		FeaturesService: support.FeatureClientStub{
			States: map[string]feature.State{
				"mcp_server_read_tools":      feature.Enabled,
				"mcp_server_artifacts_tools": feature.Enabled,
				"audit_logs":                 feature.Enabled,
			},
		},
	}

	publisher := &auditPublisherStub{err: errors.New("amqp down")}
	restore := auditlog.SetPublisherForTests(publisher)
	defer restore()

	req := callRequest(map[string]any{
		"organization_id": testOrgID,
		"scope":           scopeJobs,
		"scope_id":        testJobID,
		"path":            "agent/output.log",
		"method":          "GET",
	}, true)

	res, err := signedURLHandler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("handler error: %v", err)
	}

	msg := requireErrorText(t, res)
	if !strings.Contains(msg, "Audit logging failed") {
		t.Fatalf("expected audit failure message, got %q", msg)
	}

	if artifactClient.lastSingleSigned != nil {
		t.Fatalf("expected signed URL backend call to be skipped when audit publish fails")
	}
}

func TestArtifactsSignedURLFailsWhenAuditFeatureCheckFails(t *testing.T) {
	artifactClient := &artifacthubClientStub{
		signedURL: "https://example.com/job-signed",
	}
	provider := &support.MockProvider{
		Timeout:           time.Second,
		JobClient:         &jobClientStub{orgID: testOrgID, projectID: testProjectID},
		ArtifacthubClient: artifactClient,
		ProjectClient: &support.ProjectClientStub{
			Response: newProjectDescribeResponse(testOrgID, testProjectID, testArtifactStore),
		},
		RBACClient: support.NewRBACStub(artifactsRequiredPermissions...),
		FeaturesService: support.FeatureClientStub{
			States: map[string]feature.State{
				"mcp_server_read_tools":      feature.Enabled,
				"mcp_server_artifacts_tools": feature.Enabled,
				"audit_logs":                 feature.Enabled,
			},
			StateErrors: map[string]error{
				"audit_logs": errors.New("feature service timeout"),
			},
		},
	}

	req := callRequest(map[string]any{
		"organization_id": testOrgID,
		"scope":           scopeJobs,
		"scope_id":        testJobID,
		"path":            "agent/output.log",
		"method":          "GET",
	}, true)

	res, err := signedURLHandler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("handler error: %v", err)
	}

	msg := requireErrorText(t, res)
	if !strings.Contains(msg, "Unable to verify audit logging availability") {
		t.Fatalf("expected audit feature check failure message, got %q", msg)
	}

	if artifactClient.lastSingleSigned != nil {
		t.Fatalf("expected signed URL backend call to be skipped when audit feature check fails")
	}
}

func TestArtifactsSignedURLSkipsAuditPublishWhenAuditLogsFeatureDisabled(t *testing.T) {
	artifactClient := &artifacthubClientStub{
		signedURL: "https://example.com/job-signed",
	}
	provider := &support.MockProvider{
		Timeout:           time.Second,
		JobClient:         &jobClientStub{orgID: testOrgID, projectID: testProjectID},
		ArtifacthubClient: artifactClient,
		ProjectClient: &support.ProjectClientStub{
			Response: newProjectDescribeResponse(testOrgID, testProjectID, testArtifactStore),
		},
		RBACClient: support.NewRBACStub(artifactsRequiredPermissions...),
		FeaturesService: support.FeatureClientStub{
			State: feature.Hidden,
			States: map[string]feature.State{
				"mcp_server_read_tools":      feature.Enabled,
				"mcp_server_artifacts_tools": feature.Enabled,
				"audit_logs":                 feature.Hidden,
			},
		},
	}

	publisher := &auditPublisherStub{}
	restore := auditlog.SetPublisherForTests(publisher)
	defer restore()

	logs := captureLoggerOutput(t)

	req := callRequest(map[string]any{
		"organization_id": testOrgID,
		"scope":           scopeJobs,
		"scope_id":        testJobID,
		"path":            "agent/output.log",
		"method":          "HEAD",
	}, true)

	res, err := signedURLHandler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("handler error: %v", err)
	}
	if res == nil || res.IsError {
		t.Fatalf("expected successful response, got: %#v", res)
	}

	if len(publisher.events) != 0 {
		t.Fatalf("expected no published audit events, got %d", len(publisher.events))
	}

	expectedResourceName := fmt.Sprintf("artifacts/jobs/%s/agent/output.log", testJobID)
	output := logs.String()
	if !strings.Contains(output, "AuditLog") {
		t.Fatalf("expected stdout audit log, got %q", output)
	}
	if !strings.Contains(output, testUserID) {
		t.Fatalf("expected stdout audit log to include user_id %s, got %q", testUserID, output)
	}
	if !strings.Contains(output, testOrgID) {
		t.Fatalf("expected stdout audit log to include org_id %s, got %q", testOrgID, output)
	}
	if !strings.Contains(output, expectedResourceName) {
		t.Fatalf("expected stdout audit log to include resource_name %s, got %q", expectedResourceName, output)
	}
}

func TestArtifactsSignedURLSuccessProjectScopeWithoutProjectID(t *testing.T) {
	artifactClient := &artifacthubClientStub{
		signedURL: "https://example.com/project-signed",
	}
	rbac := support.NewRBACStub(artifactsRequiredPermissions...)
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
	if artifactClient.lastSingleSigned == nil {
		t.Fatalf("expected GetSignedURL request to be recorded")
	}
	if artifactClient.lastSingleSigned.GetArtifactId() != testArtifactStore {
		t.Fatalf("expected artifact_id %s, got %s", testArtifactStore, artifactClient.lastSingleSigned.GetArtifactId())
	}
	if len(result.URLs) != 1 {
		t.Fatalf("expected single signed URL entry, got %d", len(result.URLs))
	}
}

func TestArtifactsSignedURLAllowsEncodedSpaceAndPlusPath(t *testing.T) {
	artifactClient := &artifacthubClientStub{
		signedURL: "https://example.com/encoded",
	}
	provider := &support.MockProvider{
		Timeout:           time.Second,
		ArtifacthubClient: artifactClient,
		ProjectClient: &support.ProjectClientStub{
			Response: newProjectDescribeResponse(testOrgID, testProjectID, testArtifactStore),
		},
		RBACClient: support.NewRBACStub(artifactsRequiredPermissions...),
	}

	relativePath := "reports/build log+v1%23.txt"
	req := callRequest(map[string]any{
		"organization_id": testOrgID,
		"scope":           scopeProjects,
		"scope_id":        testProjectID,
		"path":            relativePath,
	}, true)

	res, err := signedURLHandler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("handler error: %v", err)
	}
	if res == nil || res.IsError {
		t.Fatalf("expected successful response, got: %#v", res)
	}

	if artifactClient.lastSingleSigned == nil {
		t.Fatalf("expected GetSignedURL request to be recorded")
	}
	expectedPath := fmt.Sprintf("artifacts/projects/%s/%s", testProjectID, relativePath)
	if artifactClient.lastSingleSigned.GetPath() != expectedPath {
		t.Fatalf("expected signed path %s, got %s", expectedPath, artifactClient.lastSingleSigned.GetPath())
	}
}

func TestArtifactsSignedURLUsesSingleFileRPCOnly(t *testing.T) {
	artifactClient := &artifacthubClientStub{signedURL: "https://example.com/a.log"}
	provider := &support.MockProvider{
		Timeout:           time.Second,
		ArtifacthubClient: artifactClient,
		ProjectClient: &support.ProjectClientStub{
			Response: newProjectDescribeResponse(testOrgID, testProjectID, testArtifactStore),
		},
		RBACClient: support.NewRBACStub(artifactsRequiredPermissions...),
	}

	req := callRequest(map[string]any{
		"organization_id": testOrgID,
		"scope":           scopeProjects,
		"scope_id":        testProjectID,
		"path":            "reports/a.log",
		"method":          "HEAD",
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
	if len(result.URLs) != 1 {
		t.Fatalf("expected 1 signed URL, got %d", len(result.URLs))
	}
	if artifactClient.lastSingleSigned == nil {
		t.Fatalf("expected GetSignedURL request to be recorded")
	}
	expectedPath := fmt.Sprintf("artifacts/projects/%s/reports/a.log", testProjectID)
	if artifactClient.lastSingleSigned.GetPath() != expectedPath {
		t.Fatalf("expected signed path %s, got %s", expectedPath, artifactClient.lastSingleSigned.GetPath())
	}
}

func TestArtifactsListToSignedURLFlowAllowsLiteralPercentPath(t *testing.T) {
	artifactClient := &artifacthubClientStub{
		listResp: &artifacthubpb.ListPathResponse{
			Items: []*artifacthubpb.ListItem{
				{Name: fmt.Sprintf("artifacts/projects/%s/reports/foo%%bar.txt", testProjectID), IsDirectory: false, Size: 42},
			},
		},
		signedURL: "https://example.com/literal-percent",
	}
	provider := &support.MockProvider{
		Timeout:           time.Second,
		ArtifacthubClient: artifactClient,
		ProjectClient: &support.ProjectClientStub{
			Response: newProjectDescribeResponse(testOrgID, testProjectID, testArtifactStore),
		},
		RBACClient: support.NewRBACStub(artifactsRequiredPermissions...),
	}

	listReq := callRequest(map[string]any{
		"organization_id": testOrgID,
		"scope":           scopeProjects,
		"scope_id":        testProjectID,
	}, true)

	listRes, err := listHandler(provider)(context.Background(), listReq)
	if err != nil {
		t.Fatalf("list handler error: %v", err)
	}
	if listRes == nil || listRes.IsError {
		t.Fatalf("expected successful list response, got: %#v", listRes)
	}

	listResult, ok := listRes.StructuredContent.(artifactListResult)
	if !ok {
		t.Fatalf("unexpected structured content type: %T", listRes.StructuredContent)
	}
	if len(listResult.Artifacts) != 1 {
		t.Fatalf("expected one artifact from list, got %d", len(listResult.Artifacts))
	}
	relativePath := listResult.Artifacts[0].Path
	if relativePath != "reports/foo%bar.txt" {
		t.Fatalf("expected literal percent path, got %q", relativePath)
	}

	signedReq := callRequest(map[string]any{
		"organization_id": testOrgID,
		"scope":           scopeProjects,
		"scope_id":        testProjectID,
		"path":            relativePath,
	}, true)

	signedRes, err := signedURLHandler(provider)(context.Background(), signedReq)
	if err != nil {
		t.Fatalf("signed handler error: %v", err)
	}
	if signedRes == nil || signedRes.IsError {
		t.Fatalf("expected successful signed-url response, got: %#v", signedRes)
	}

	if artifactClient.lastSingleSigned == nil {
		t.Fatalf("expected GetSignedURL request to be recorded")
	}
	expectedPath := fmt.Sprintf("artifacts/projects/%s/%s", testProjectID, relativePath)
	if artifactClient.lastSingleSigned.GetPath() != expectedPath {
		t.Fatalf("expected signed path %s, got %s", expectedPath, artifactClient.lastSingleSigned.GetPath())
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
		"path":            "agent/output.log",
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
		RBACClient:        support.NewRBACStub("organization.view"),
	}

	req := callRequest(map[string]any{
		"organization_id": testOrgID,
		"scope":           scopeJobs,
		"scope_id":        testJobID,
		"path":            "agent/output.log",
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
	rbac := support.NewRBACStub("organization.view")
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
	if artifactClient.lastSingleSigned != nil {
		t.Fatalf("expected signed URL RPC not to be called on RBAC deny")
	}
}

func TestArtifactsSignedURLProjectScopeMismatchRejected(t *testing.T) {
	rbac := support.NewRBACStub(artifactsRequiredPermissions...)
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

func TestArtifactsSignedURLProjectScopeOrgMismatchRejectedBeforeRBAC(t *testing.T) {
	rbac := support.NewRBACStub(artifactsRequiredPermissions...)
	projectClient := &support.ProjectClientStub{
		Response: newProjectDescribeResponse(testOtherOrgID, testProjectID, testArtifactStore),
	}
	provider := &support.MockProvider{
		Timeout:       time.Second,
		ProjectClient: projectClient,
		RBACClient:    rbac,
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

	msg := requireErrorText(t, res)
	if !strings.Contains(msg, "outside the authorized organization scope") {
		t.Fatalf("expected organization scope mismatch error, got %q", msg)
	}
	if len(rbac.LastRequests) != 0 {
		t.Fatalf("expected no RBAC request on org mismatch, got %d", len(rbac.LastRequests))
	}
	if projectClient.LastDescribe == nil {
		t.Fatalf("expected project describe to run before RBAC")
	}
}

func TestArtifactsSignedURLWorkflowScopeProjectMismatchRejected(t *testing.T) {
	rbac := support.NewRBACStub(artifactsRequiredPermissions...)
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
	rbac := support.NewRBACStub(artifactsRequiredPermissions...)
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

func TestArtifactsSignedURLWorkflowScopeOrgMismatchRejected(t *testing.T) {
	rbac := support.NewRBACStub(artifactsRequiredPermissions...)
	workflowClient := &support.WorkflowClientStub{
		DescribeResp: &workflowpb.DescribeResponse{
			Status: &statuspb.Status{Code: code.Code_OK},
			Workflow: &workflowpb.WorkflowDetails{
				WfId:           testWorkflowID,
				OrganizationId: testOtherOrgID,
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
		"path":            "debug/workflow_logs.txt",
	}, true)

	res, err := signedURLHandler(provider)(context.Background(), req)
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

func TestArtifactsSignedURLWorkflowDescribeError(t *testing.T) {
	provider := &support.MockProvider{
		Timeout:        time.Second,
		WorkflowClient: &support.WorkflowClientStub{DescribeErr: errors.New("workflow down")},
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
	if !strings.Contains(msg, "workflow describe RPC failed") {
		t.Fatalf("expected workflow describe failure, got %q", msg)
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

func TestArtifactsListReturnedMetadata(t *testing.T) {
	artifactClient := &artifacthubClientStub{
		listResp: &artifacthubpb.ListPathResponse{
			Items: []*artifacthubpb.ListItem{
				{Name: fmt.Sprintf("artifacts/projects/%s/a.txt", testProjectID), IsDirectory: false, Size: 1},
				{Name: fmt.Sprintf("artifacts/projects/%s/b.txt", testProjectID), IsDirectory: false, Size: 2},
			},
		},
	}
	provider := &support.MockProvider{
		Timeout:           time.Second,
		ArtifacthubClient: artifactClient,
		ProjectClient: &support.ProjectClientStub{
			Response: newProjectDescribeResponse(testOrgID, testProjectID, testArtifactStore),
		},
		RBACClient: support.NewRBACStub(artifactsRequiredPermissions...),
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

	if len(result.Artifacts) != 2 {
		t.Fatalf("expected 2 artifacts, got %d", len(result.Artifacts))
	}
	if result.Artifacts[0].Path != "a.txt" || result.Artifacts[1].Path != "b.txt" {
		t.Fatalf("unexpected artifacts: %#v", result.Artifacts)
	}
	if result.Page.Returned != 2 {
		t.Fatalf("expected returned 2, got %d", result.Page.Returned)
	}
	if result.Page.Truncated {
		t.Fatalf("expected non-truncated page metadata")
	}
	if artifactClient.lastList == nil {
		t.Fatalf("expected ListPath request to be recorded")
	}
}

func TestArtifactsListStructuredContentCapped(t *testing.T) {
	items := make([]*artifacthubpb.ListItem, 0, 1500)
	for i := 0; i < 1500; i++ {
		items = append(items, &artifacthubpb.ListItem{
			Name:        fmt.Sprintf("artifacts/projects/%s/file-%04d.txt", testProjectID, i),
			IsDirectory: false,
			Size:        int64(i + 1),
		})
	}

	artifactClient := &artifacthubClientStub{
		listResp: &artifacthubpb.ListPathResponse{Items: items},
	}
	provider := &support.MockProvider{
		Timeout:           time.Second,
		ArtifacthubClient: artifactClient,
		ProjectClient: &support.ProjectClientStub{
			Response: newProjectDescribeResponse(testOrgID, testProjectID, testArtifactStore),
		},
		RBACClient: support.NewRBACStub(artifactsRequiredPermissions...),
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
	if len(result.Artifacts) != artifactListMaxItems {
		t.Fatalf("expected %d artifacts after capping, got %d", artifactListMaxItems, len(result.Artifacts))
	}
	if result.Page.Returned != artifactListMaxItems {
		t.Fatalf("expected returned %d, got %d", artifactListMaxItems, result.Page.Returned)
	}
	if !result.Page.Truncated {
		t.Fatalf("expected truncated page metadata")
	}
	if result.Artifacts[0].Path != "file-0000.txt" {
		t.Fatalf("unexpected first artifact path: %s", result.Artifacts[0].Path)
	}
	if result.Artifacts[artifactListMaxItems-1].Path != "file-0999.txt" {
		t.Fatalf("unexpected last artifact path: %s", result.Artifacts[artifactListMaxItems-1].Path)
	}
}

func TestArtifactsListRootEmptyReturnsSuccess(t *testing.T) {
	provider := &support.MockProvider{
		Timeout:           time.Second,
		ArtifacthubClient: &artifacthubClientStub{listResp: &artifacthubpb.ListPathResponse{}},
		ProjectClient: &support.ProjectClientStub{
			Response: newProjectDescribeResponse(testOrgID, testProjectID, testArtifactStore),
		},
		RBACClient: support.NewRBACStub(artifactsRequiredPermissions...),
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
	if len(result.Artifacts) != 0 {
		t.Fatalf("expected empty artifacts list, got %d", len(result.Artifacts))
	}
	if result.Page.Returned != 0 {
		t.Fatalf("unexpected page metadata: %#v", result.Page)
	}
	if result.Page.Truncated {
		t.Fatalf("expected non-truncated page metadata")
	}
}

func TestArtifactsListNonRootEmptyDirectoryReturnsSuccess(t *testing.T) {
	artifactClient := &artifacthubClientStub{
		listRespByPath: map[string]*artifacthubpb.ListPathResponse{
			fmt.Sprintf("artifacts/projects/%s/empty-dir", testProjectID): {},
		},
	}
	provider := &support.MockProvider{
		Timeout:           time.Second,
		ArtifacthubClient: artifactClient,
		ProjectClient: &support.ProjectClientStub{
			Response: newProjectDescribeResponse(testOrgID, testProjectID, testArtifactStore),
		},
		RBACClient: support.NewRBACStub(artifactsRequiredPermissions...),
	}

	req := callRequest(map[string]any{
		"organization_id": testOrgID,
		"scope":           scopeProjects,
		"scope_id":        testProjectID,
		"path":            "empty-dir",
	}, true)

	res, err := listHandler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("handler error: %v", err)
	}
	if res == nil || res.IsError {
		t.Fatalf("expected successful response for empty non-root path, got %#v", res)
	}

	result, ok := res.StructuredContent.(artifactListResult)
	if !ok {
		t.Fatalf("unexpected structured content type: %T", res.StructuredContent)
	}
	if result.Path != "empty-dir" {
		t.Fatalf("expected path empty-dir, got %q", result.Path)
	}
	if len(result.Artifacts) != 0 {
		t.Fatalf("expected empty artifacts list, got %d", len(result.Artifacts))
	}
	if result.Page.Returned != 0 {
		t.Fatalf("expected returned 0, got %d", result.Page.Returned)
	}
	if result.Page.Truncated {
		t.Fatalf("expected non-truncated page metadata")
	}
	if artifactClient.lastList == nil {
		t.Fatalf("expected ListPath request to be recorded")
	}
	if artifactClient.lastList.GetPath() != fmt.Sprintf("artifacts/projects/%s/empty-dir", testProjectID) {
		t.Fatalf("unexpected list path: %q", artifactClient.lastList.GetPath())
	}
}

func TestArtifactsListMissingArtifactStoreID(t *testing.T) {
	provider := &support.MockProvider{
		Timeout: time.Second,
		ProjectClient: &support.ProjectClientStub{
			Response: newProjectDescribeResponse(testOrgID, testProjectID, ""),
		},
		RBACClient: support.NewRBACStub(artifactsRequiredPermissions...),
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
	msg := requireErrorText(t, res)
	if !strings.Contains(msg, "project is missing an artifact_store_id") {
		t.Fatalf("expected missing artifact_store_id error, got %q", msg)
	}
}

func TestArtifactsListArtifacthubRPCError(t *testing.T) {
	provider := &support.MockProvider{
		Timeout:           time.Second,
		ArtifacthubClient: &artifacthubClientStub{listErr: errors.New("list boom")},
		JobClient:         &jobClientStub{orgID: testOrgID, projectID: testProjectID},
		ProjectClient: &support.ProjectClientStub{
			Response: newProjectDescribeResponse(testOrgID, testProjectID, testArtifactStore),
		},
		RBACClient: support.NewRBACStub(artifactsRequiredPermissions...),
	}

	req := callRequest(map[string]any{
		"organization_id": testOrgID,
		"scope":           scopeJobs,
		"scope_id":        testJobID,
	}, true)

	logs := captureLoggerOutput(t)

	res, err := listHandler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("handler error: %v", err)
	}
	msg := requireErrorText(t, res)
	if !strings.Contains(msg, "artifacthub ListPath failed") {
		t.Fatalf("expected artifacthub list failure, got %q", msg)
	}

	output := logs.String()
	if !strings.Contains(output, "AuditLog") {
		t.Fatalf("expected stdout audit log even on list failure, got %q", output)
	}
	if !strings.Contains(output, `"operation":"List"`) {
		t.Fatalf("expected List operation in stdout audit log, got %q", output)
	}
}

func TestArtifactsListArtifacthubFailedPreconditionError(t *testing.T) {
	provider := &support.MockProvider{
		Timeout: time.Second,
		ArtifacthubClient: &artifacthubClientStub{
			listErr: grpcstatus.Error(grpccodes.FailedPrecondition, "artifact path is not allowed"),
		},
		JobClient: &jobClientStub{orgID: testOrgID, projectID: testProjectID},
		ProjectClient: &support.ProjectClientStub{
			Response: newProjectDescribeResponse(testOrgID, testProjectID, testArtifactStore),
		},
		RBACClient: support.NewRBACStub(artifactsRequiredPermissions...),
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
	if !strings.Contains(msg, "failed precondition") || !strings.Contains(msg, "artifact path is not allowed") {
		t.Fatalf("expected failed precondition details, got %q", msg)
	}
}

func TestArtifactsListArtifacthubPathNotFoundErrorMapped(t *testing.T) {
	provider := &support.MockProvider{
		Timeout: time.Second,
		ArtifacthubClient: &artifacthubClientStub{
			listErr: grpcstatus.Error(grpccodes.NotFound, "whatever"),
		},
		JobClient: &jobClientStub{orgID: testOrgID, projectID: testProjectID},
		ProjectClient: &support.ProjectClientStub{
			Response: newProjectDescribeResponse(testOrgID, testProjectID, testArtifactStore),
		},
		RBACClient: support.NewRBACStub(artifactsRequiredPermissions...),
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
	if msg != "artifact path not found" {
		t.Fatalf("expected clean path not found message, got %q", msg)
	}
}

func TestArtifactsSignedURLArtifacthubRPCError(t *testing.T) {
	provider := &support.MockProvider{
		Timeout:           time.Second,
		ArtifacthubClient: &artifacthubClientStub{singleSignedErr: errors.New("signed boom")},
		JobClient:         &jobClientStub{orgID: testOrgID, projectID: testProjectID},
		ProjectClient: &support.ProjectClientStub{
			Response: newProjectDescribeResponse(testOrgID, testProjectID, testArtifactStore),
		},
		RBACClient: support.NewRBACStub(artifactsRequiredPermissions...),
	}

	publisher := &auditPublisherStub{}
	restore := auditlog.SetPublisherForTests(publisher)
	defer restore()

	req := callRequest(map[string]any{
		"organization_id": testOrgID,
		"scope":           scopeJobs,
		"scope_id":        testJobID,
		"path":            "agent/output.log",
	}, true)

	res, err := signedURLHandler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("handler error: %v", err)
	}
	msg := requireErrorText(t, res)
	if !strings.Contains(msg, "artifacthub GetSignedURL failed") {
		t.Fatalf("expected artifacthub signed URL failure, got %q", msg)
	}

	if len(publisher.events) != 1 {
		t.Fatalf("expected one audit event before signed URL failure, got %d", len(publisher.events))
	}
}

func TestArtifactsSignedURLResolvesJobFullLogsByPriority(t *testing.T) {
	artifactClient := &artifacthubClientStub{
		listRespByPath: map[string]*artifacthubpb.ListPathResponse{
			fmt.Sprintf("artifacts/jobs/%s/agent/", testJobID): {
				Items: []*artifacthubpb.ListItem{
					{Name: fmt.Sprintf("artifacts/jobs/%s/agent/job_logs.txt.gz", testJobID), IsDirectory: false, Size: 123},
					{Name: fmt.Sprintf("artifacts/jobs/%s/agent/job_logs.txt", testJobID), IsDirectory: false, Size: 456},
				},
			},
		},
		signedURL: "https://example.com/full-log",
	}
	provider := &support.MockProvider{
		Timeout:           time.Second,
		ArtifacthubClient: artifactClient,
		JobClient:         &jobClientStub{orgID: testOrgID, projectID: testProjectID},
		ProjectClient: &support.ProjectClientStub{
			Response: newProjectDescribeResponse(testOrgID, testProjectID, testArtifactStore),
		},
		RBACClient: support.NewRBACStub(artifactsRequiredPermissions...),
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
	if result.Path != "agent/job_logs.txt" {
		t.Fatalf("expected resolved path agent/job_logs.txt, got %q", result.Path)
	}
	if artifactClient.lastList == nil {
		t.Fatalf("expected agent directory listing before signing")
	}
	if artifactClient.lastList.GetPath() != fmt.Sprintf("artifacts/jobs/%s/agent/", testJobID) {
		t.Fatalf("unexpected list path: %q", artifactClient.lastList.GetPath())
	}
	if artifactClient.lastList.GetUnwrapDirectories() {
		t.Fatalf("expected unwrap_directories=false for agent listing")
	}
	if artifactClient.lastSingleSigned == nil {
		t.Fatalf("expected GetSignedURL request to be recorded")
	}
	expectedPath := fmt.Sprintf("artifacts/jobs/%s/agent/job_logs.txt", testJobID)
	if artifactClient.lastSingleSigned.GetPath() != expectedPath {
		t.Fatalf("expected signed path %s, got %s", expectedPath, artifactClient.lastSingleSigned.GetPath())
	}
}

func TestArtifactsSignedURLResolvesJobFullLogsToGzipWhenPlainMissing(t *testing.T) {
	artifactClient := &artifacthubClientStub{
		listRespByPath: map[string]*artifacthubpb.ListPathResponse{
			fmt.Sprintf("artifacts/jobs/%s/agent/", testJobID): {
				Items: []*artifacthubpb.ListItem{
					{Name: fmt.Sprintf("artifacts/jobs/%s/agent/job_logs.txt.gz", testJobID), IsDirectory: false, Size: 123},
				},
			},
		},
		signedURL: "https://example.com/full-log-gz",
	}
	provider := &support.MockProvider{
		Timeout:           time.Second,
		ArtifacthubClient: artifactClient,
		JobClient:         &jobClientStub{orgID: testOrgID, projectID: testProjectID},
		ProjectClient: &support.ProjectClientStub{
			Response: newProjectDescribeResponse(testOrgID, testProjectID, testArtifactStore),
		},
		RBACClient: support.NewRBACStub(artifactsRequiredPermissions...),
	}

	req := callRequest(map[string]any{
		"organization_id": testOrgID,
		"scope":           scopeJobs,
		"scope_id":        testJobID,
		"path":            "job_logs.txt",
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
	if result.Path != "agent/job_logs.txt.gz" {
		t.Fatalf("expected resolved path agent/job_logs.txt.gz, got %q", result.Path)
	}
	if artifactClient.lastSingleSigned == nil {
		t.Fatalf("expected GetSignedURL request to be recorded")
	}
	expectedPath := fmt.Sprintf("artifacts/jobs/%s/agent/job_logs.txt.gz", testJobID)
	if artifactClient.lastSingleSigned.GetPath() != expectedPath {
		t.Fatalf("expected signed path %s, got %s", expectedPath, artifactClient.lastSingleSigned.GetPath())
	}
}

func TestArtifactsSignedURLJobFullLogsReturnsNotFoundWhenMissing(t *testing.T) {
	artifactClient := &artifacthubClientStub{
		listRespByPath: map[string]*artifacthubpb.ListPathResponse{
			fmt.Sprintf("artifacts/jobs/%s/agent/", testJobID): {
				Items: []*artifacthubpb.ListItem{
					{Name: fmt.Sprintf("artifacts/jobs/%s/agent/other.log", testJobID), IsDirectory: false, Size: 10},
				},
			},
		},
		signedURL: "https://example.com/should-not-be-used",
	}
	provider := &support.MockProvider{
		Timeout:           time.Second,
		ArtifacthubClient: artifactClient,
		JobClient:         &jobClientStub{orgID: testOrgID, projectID: testProjectID},
		ProjectClient: &support.ProjectClientStub{
			Response: newProjectDescribeResponse(testOrgID, testProjectID, testArtifactStore),
		},
		RBACClient: support.NewRBACStub(artifactsRequiredPermissions...),
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
	if msg != "artifact path not found" {
		t.Fatalf("expected path not found, got %q", msg)
	}
	if artifactClient.lastSingleSigned != nil {
		t.Fatalf("expected no signed URL request when full log files are missing")
	}
}

func TestArtifactsSignedURLArtifacthubPathNotFoundErrorMapped(t *testing.T) {
	provider := &support.MockProvider{
		Timeout: time.Second,
		ArtifacthubClient: &artifacthubClientStub{
			singleSignedErr: grpcstatus.Error(grpccodes.NotFound, "whatever"),
		},
		JobClient: &jobClientStub{orgID: testOrgID, projectID: testProjectID},
		ProjectClient: &support.ProjectClientStub{
			Response: newProjectDescribeResponse(testOrgID, testProjectID, testArtifactStore),
		},
		RBACClient: support.NewRBACStub(artifactsRequiredPermissions...),
	}

	req := callRequest(map[string]any{
		"organization_id": testOrgID,
		"scope":           scopeJobs,
		"scope_id":        testJobID,
		"path":            "agent/missing.txt",
	}, true)

	res, err := signedURLHandler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("handler error: %v", err)
	}

	msg := requireErrorText(t, res)
	if msg != "artifact path not found" {
		t.Fatalf("expected clean path not found message, got %q", msg)
	}
}

func TestArtifactsSignedURLArtifacthubStoreNotFoundErrorMapped(t *testing.T) {
	provider := &support.MockProvider{
		Timeout: time.Second,
		ArtifacthubClient: &artifacthubClientStub{
			singleSignedErr: grpcstatus.Error(grpccodes.NotFound, "artifact store not found"),
		},
		JobClient: &jobClientStub{orgID: testOrgID, projectID: testProjectID},
		ProjectClient: &support.ProjectClientStub{
			Response: newProjectDescribeResponse(testOrgID, testProjectID, testArtifactStore),
		},
		RBACClient: support.NewRBACStub(artifactsRequiredPermissions...),
	}

	req := callRequest(map[string]any{
		"organization_id": testOrgID,
		"scope":           scopeJobs,
		"scope_id":        testJobID,
		"path":            "agent/missing.txt",
	}, true)

	res, err := signedURLHandler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("handler error: %v", err)
	}

	msg := requireErrorText(t, res)
	if msg != "artifact store not found" {
		t.Fatalf("expected clean store not found message, got %q", msg)
	}
}

func TestArtifactsSignedURLArtifacthubFailedPreconditionError(t *testing.T) {
	provider := &support.MockProvider{
		Timeout: time.Second,
		ArtifacthubClient: &artifacthubClientStub{
			singleSignedErr: grpcstatus.Error(grpccodes.FailedPrecondition, "artifact path is not allowed"),
		},
		JobClient: &jobClientStub{orgID: testOrgID, projectID: testProjectID},
		ProjectClient: &support.ProjectClientStub{
			Response: newProjectDescribeResponse(testOrgID, testProjectID, testArtifactStore),
		},
		RBACClient: support.NewRBACStub(artifactsRequiredPermissions...),
	}

	req := callRequest(map[string]any{
		"organization_id": testOrgID,
		"scope":           scopeJobs,
		"scope_id":        testJobID,
		"path":            "agent/output.log",
	}, true)

	res, err := signedURLHandler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("handler error: %v", err)
	}
	msg := requireErrorText(t, res)
	if !strings.Contains(msg, "failed precondition") || !strings.Contains(msg, "artifact path is not allowed") {
		t.Fatalf("expected failed precondition details, got %q", msg)
	}
}

func TestArtifactsListWorkflowDescribeError(t *testing.T) {
	provider := &support.MockProvider{
		Timeout:        time.Second,
		WorkflowClient: &support.WorkflowClientStub{DescribeErr: errors.New("workflow down")},
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
	if !strings.Contains(msg, "workflow describe RPC failed") {
		t.Fatalf("expected workflow describe failure, got %q", msg)
	}
}

func TestArtifactsListJobDescribeError(t *testing.T) {
	provider := &support.MockProvider{
		Timeout:   time.Second,
		JobClient: &jobClientStub{describeErr: errors.New("job down")},
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
	if !strings.Contains(msg, "describe job RPC failed") {
		t.Fatalf("expected job describe failure, got %q", msg)
	}
}

func TestArtifactsListProjectDescribeError(t *testing.T) {
	provider := &support.MockProvider{
		Timeout: time.Second,
		ProjectClient: &support.ProjectClientStub{
			Err: errors.New("project down"),
		},
		RBACClient: support.NewRBACStub(artifactsRequiredPermissions...),
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
	msg := requireErrorText(t, res)
	if !strings.Contains(msg, "describe project RPC failed") {
		t.Fatalf("expected project describe failure, got %q", msg)
	}
}

func TestArtifactsSignedURLMissingPathRejected(t *testing.T) {
	req := callRequest(map[string]any{
		"organization_id": testOrgID,
		"scope":           scopeProjects,
		"scope_id":        testProjectID,
	}, true)

	res, err := signedURLHandler(&support.MockProvider{Timeout: time.Second})(context.Background(), req)
	if err != nil {
		t.Fatalf("handler error: %v", err)
	}
	msg := requireErrorText(t, res)
	if !strings.Contains(msg, "path must be present") {
		t.Fatalf("expected missing path error, got %q", msg)
	}
}

func TestNormalizeMethodDefaultsToGET(t *testing.T) {
	got, err := normalizeMethod("")
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if got != "GET" {
		t.Fatalf("expected GET, got %q", got)
	}
}

func TestSanitizeRelativePathRejectsControlAndEncodedTraversal(t *testing.T) {
	testCases := []struct {
		name    string
		path    string
		message string
	}{
		{name: "control rune", path: "foo\x00bar", message: "control characters"},
		{name: "encoded parent", path: "foo/%2e%2e/bar", message: "path traversal"},
		{name: "encoded slash", path: "foo/%2Fbar", message: "encoded path separators"},
		{name: "double encoded parent", path: "foo/%252e%252e/bar", message: "path traversal"},
		{name: "backslash", path: `foo\bar`, message: "invalid path"},
		{name: "nested parent", path: "foo/../../secret.txt", message: "path traversal"},
	}

	for _, tc := range testCases {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			_, err := sanitizeRelativePath(tc.path, true)
			if err == nil {
				t.Fatalf("expected error for path %q", tc.path)
			}
			if !strings.Contains(err.Error(), tc.message) {
				t.Fatalf("expected %q in error, got %q", tc.message, err.Error())
			}
		})
	}
}

func TestSanitizeRelativePathRejectsLeadingTrailingWhitespace(t *testing.T) {
	testCases := []struct {
		name    string
		path    string
		message string
	}{
		{name: "path leading whitespace", path: " reports/a.txt", message: "leading or trailing whitespace"},
		{name: "path trailing whitespace", path: "reports/a.txt ", message: "leading or trailing whitespace"},
		{name: "segment trailing whitespace", path: "reports /a.txt", message: "segments must not contain leading or trailing whitespace"},
		{name: "segment leading whitespace", path: "reports/ a.txt", message: "segments must not contain leading or trailing whitespace"},
		{name: "encoded segment leading whitespace", path: "reports/%20a.txt", message: "segments must not contain leading or trailing whitespace"},
		{name: "encoded segment trailing whitespace", path: "reports/a.txt%20", message: "leading or trailing whitespace"},
	}

	for _, tc := range testCases {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			_, err := sanitizeRelativePath(tc.path, true)
			if err == nil {
				t.Fatalf("expected error for path %q", tc.path)
			}
			if !strings.Contains(err.Error(), tc.message) {
				t.Fatalf("expected %q in error, got %q", tc.message, err.Error())
			}
		})
	}
}

func TestSanitizeRelativePathAllowsSafeEncodedLookingName(t *testing.T) {
	got, err := sanitizeRelativePath("reports/report%2ejson", true)
	if err != nil {
		t.Fatalf("expected encoded-looking safe path to be allowed, got error: %v", err)
	}
	if got != "reports/report%2ejson" {
		t.Fatalf("expected path to be preserved, got %q", got)
	}
}

func TestSanitizeRelativePathAllowsLiteralPercentCharacters(t *testing.T) {
	testCases := []string{
		"reports/foo%bar.txt",
		"reports/foo%zz.txt",
	}

	for _, tc := range testCases {
		got, err := sanitizeRelativePath(tc, true)
		if err != nil {
			t.Fatalf("expected literal percent path %q to be allowed, got error: %v", tc, err)
		}
		if got != tc {
			t.Fatalf("expected path %q to be preserved, got %q", tc, got)
		}
	}
}

func TestSanitizeRelativePathAllowsInternalWhitespace(t *testing.T) {
	got, err := sanitizeRelativePath("reports/build log.txt", true)
	if err != nil {
		t.Fatalf("expected internal whitespace path to be allowed, got error: %v", err)
	}
	if got != "reports/build log.txt" {
		t.Fatalf("expected path to be preserved, got %q", got)
	}
}

func TestSerializeListItemsSkipsUnexpectedPrefixes(t *testing.T) {
	items := []*artifacthubpb.ListItem{
		{Name: fmt.Sprintf("artifacts/projects/%s/reports/junit.xml", testProjectID), IsDirectory: false, Size: 10},
		{Name: fmt.Sprintf("artifacts/workflows/%s/reports/junit.xml", testWorkflowID), IsDirectory: false, Size: 20},
		{Name: "unexpected/path/file.txt", IsDirectory: false, Size: 30},
	}

	result := serializeListItems(items, scopeProjects, testProjectID)
	if len(result) != 1 {
		t.Fatalf("expected 1 matching item, got %d: %#v", len(result), result)
	}
	if result[0].Path != "reports/junit.xml" {
		t.Fatalf("expected relative path reports/junit.xml, got %s", result[0].Path)
	}
}

func TestArtifactsListMissingUserHeaderCheckedBeforeFeatureFlag(t *testing.T) {
	provider := &support.MockProvider{
		Timeout:         time.Second,
		FeaturesService: support.FeatureClientStub{State: feature.Hidden},
	}

	req := callRequest(map[string]any{
		"organization_id": testOrgID,
		"scope":           scopeProjects,
		"scope_id":        testProjectID,
	}, false)

	res, err := listHandler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("handler error: %v", err)
	}
	msg := requireErrorText(t, res)
	if !strings.Contains(msg, "X-Semaphore-User-ID") {
		t.Fatalf("expected auth header error, got %q", msg)
	}
	if strings.Contains(msg, "read tools are disabled") {
		t.Fatalf("expected header error before feature gate, got %q", msg)
	}
}

func TestArtifactsSignedURLMissingUserHeaderCheckedBeforeFeatureFlag(t *testing.T) {
	provider := &support.MockProvider{
		Timeout:         time.Second,
		FeaturesService: support.FeatureClientStub{State: feature.Hidden},
	}

	req := callRequest(map[string]any{
		"organization_id": testOrgID,
		"scope":           scopeProjects,
		"scope_id":        testProjectID,
		"path":            "releases/build.tar.gz",
	}, false)

	res, err := signedURLHandler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("handler error: %v", err)
	}
	msg := requireErrorText(t, res)
	if !strings.Contains(msg, "X-Semaphore-User-ID") {
		t.Fatalf("expected auth header error, got %q", msg)
	}
	if strings.Contains(msg, "read tools are disabled") {
		t.Fatalf("expected header error before feature gate, got %q", msg)
	}
}

func TestArtifactsListArtifactsToolsFeatureDisabled(t *testing.T) {
	provider := &support.MockProvider{
		Timeout: time.Second,
		FeaturesService: support.FeatureClientStub{
			States: map[string]feature.State{
				"mcp_server_read_tools":      feature.Enabled,
				"mcp_server_artifacts_tools": feature.Hidden,
			},
		},
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
	msg := requireErrorText(t, res)
	if !strings.Contains(strings.ToLower(msg), "artifact operations are disabled") {
		t.Fatalf("expected mcp_server_artifacts_tools disabled error, got %q", msg)
	}
}

func TestArtifactsSignedURLArtifactsToolsFeatureDisabled(t *testing.T) {
	provider := &support.MockProvider{
		Timeout: time.Second,
		FeaturesService: support.FeatureClientStub{
			States: map[string]feature.State{
				"mcp_server_read_tools":      feature.Enabled,
				"mcp_server_artifacts_tools": feature.Hidden,
			},
		},
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
	msg := requireErrorText(t, res)
	if !strings.Contains(strings.ToLower(msg), "artifact operations are disabled") {
		t.Fatalf("expected mcp_server_artifacts_tools disabled error, got %q", msg)
	}
}

func TestArtifactsListBothPermissionsAccepted(t *testing.T) {
	provider := &support.MockProvider{
		Timeout:           time.Second,
		ArtifacthubClient: &artifacthubClientStub{},
		JobClient:         &jobClientStub{orgID: testOrgID, projectID: testProjectID},
		ProjectClient: &support.ProjectClientStub{
			Response: newProjectDescribeResponse(testOrgID, testProjectID, testArtifactStore),
		},
		RBACClient: support.NewRBACStub(artifactsRequiredPermissions...),
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
	if res == nil || res.IsError {
		t.Fatalf("expected successful response with both project permissions, got %#v", res)
	}
}

func TestArtifactsListProjectViewOnlyIsDenied(t *testing.T) {
	provider := &support.MockProvider{
		Timeout:           time.Second,
		ArtifacthubClient: &artifacthubClientStub{},
		JobClient:         &jobClientStub{orgID: testOrgID, projectID: testProjectID},
		ProjectClient: &support.ProjectClientStub{
			Response: newProjectDescribeResponse(testOrgID, testProjectID, testArtifactStore),
		},
		RBACClient: support.NewRBACStub("project.view"),
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
		t.Fatalf("expected permission denied error for project.view-only user, got %q", msg)
	}
}

func TestArtifactsSignedURLProjectViewOnlyIsDenied(t *testing.T) {
	provider := &support.MockProvider{
		Timeout:           time.Second,
		ArtifacthubClient: &artifacthubClientStub{signedURL: "https://example.com/ignored"},
		JobClient:         &jobClientStub{orgID: testOrgID, projectID: testProjectID},
		ProjectClient: &support.ProjectClientStub{
			Response: newProjectDescribeResponse(testOrgID, testProjectID, testArtifactStore),
		},
		RBACClient: support.NewRBACStub("project.view"),
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
		t.Fatalf("expected permission denied error for project.view-only user, got %q", msg)
	}
}

func TestArtifactListPathRPCPublishesMetrics(t *testing.T) {
	metrics := &artifactCallMetricsStub{}
	orig := newArtifactCallMetrics
	newArtifactCallMetrics = func(context.Context, string, string) artifactCallMetrics {
		return metrics
	}
	t.Cleanup(func() { newArtifactCallMetrics = orig })

	provider := &support.MockProvider{
		Timeout:           time.Second,
		ArtifacthubClient: &artifacthubClientStub{listResp: &artifacthubpb.ListPathResponse{}},
	}

	_, err := listPathRPC(context.Background(), provider, testOrgID, &artifacthubpb.ListPathRequest{
		ArtifactId: testArtifactStore,
		Path:       "artifacts/projects/test/",
	})
	if err != nil {
		t.Fatalf("listPathRPC error: %v", err)
	}

	if metrics.total != 1 || metrics.success != 1 || metrics.failure != 0 || metrics.duration != 1 {
		t.Fatalf("unexpected metrics counters: %#v", metrics)
	}
}

func TestArtifactGetSignedURLRPCPublishesFailureMetrics(t *testing.T) {
	metrics := &artifactCallMetricsStub{}
	orig := newArtifactCallMetrics
	newArtifactCallMetrics = func(context.Context, string, string) artifactCallMetrics {
		return metrics
	}
	t.Cleanup(func() { newArtifactCallMetrics = orig })

	provider := &support.MockProvider{
		Timeout:           time.Second,
		ArtifacthubClient: &artifacthubClientStub{singleSignedErr: errors.New("boom")},
	}

	_, err := getSignedURL(context.Background(), provider, testOrgID, testArtifactStore, "artifacts/projects/test/a.log", "GET")
	if err == nil {
		t.Fatalf("expected getSignedURL error")
	}

	if metrics.total != 1 || metrics.success != 0 || metrics.failure != 1 || metrics.duration != 1 {
		t.Fatalf("unexpected metrics counters: %#v", metrics)
	}
}

func TestRegisterAddsBothArtifactTools(t *testing.T) {
	srv := server.NewMCPServer("test-server", "0.0.1")
	Register(srv, &support.MockProvider{Timeout: time.Second})

	registered := srv.ListTools()
	if _, ok := registered[listToolName]; !ok {
		t.Fatalf("expected %s to be registered", listToolName)
	}
	if _, ok := registered[signedURLToolName]; !ok {
		t.Fatalf("expected %s to be registered", signedURLToolName)
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

func captureLoggerOutput(t *testing.T) *bytes.Buffer {
	t.Helper()

	logger := logging.Logger()
	var buf bytes.Buffer
	previous := logger.Out
	logger.SetOutput(&buf)
	t.Cleanup(func() {
		logger.SetOutput(previous)
	})

	return &buf
}

type auditPublisherStub struct {
	events []*auditpb.Event
	err    error
}

func (s *auditPublisherStub) Publish(_ context.Context, event *auditpb.Event) error {
	s.events = append(s.events, event)
	return s.err
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

	listResp         *artifacthubpb.ListPathResponse
	listRespByPath   map[string]*artifacthubpb.ListPathResponse
	listErr          error
	listErrByPath    map[string]error
	lastList         *artifacthubpb.ListPathRequest
	signedURL        string
	singleSignedURL  string
	singleSignedErr  error
	lastSingleSigned *artifacthubpb.GetSignedURLRequest
}

func (s *artifacthubClientStub) ListPath(ctx context.Context, in *artifacthubpb.ListPathRequest, opts ...grpc.CallOption) (*artifacthubpb.ListPathResponse, error) {
	s.lastList = in
	if err, ok := s.listErrByPath[in.GetPath()]; ok {
		return nil, err
	}
	if s.listErr != nil {
		return nil, s.listErr
	}
	if resp, ok := s.listRespByPath[in.GetPath()]; ok {
		return resp, nil
	}
	if s.listResp != nil {
		return s.listResp, nil
	}
	return &artifacthubpb.ListPathResponse{}, nil
}

func (s *artifacthubClientStub) GetSignedURL(ctx context.Context, in *artifacthubpb.GetSignedURLRequest, opts ...grpc.CallOption) (*artifacthubpb.GetSignedURLResponse, error) {
	s.lastSingleSigned = in
	if s.singleSignedErr != nil {
		return nil, s.singleSignedErr
	}
	if s.singleSignedURL != "" {
		return &artifacthubpb.GetSignedURLResponse{Url: s.singleSignedURL}, nil
	}
	if s.signedURL != "" {
		return &artifacthubpb.GetSignedURLResponse{Url: s.signedURL}, nil
	}
	return &artifacthubpb.GetSignedURLResponse{}, nil
}

type artifactCallMetricsStub struct {
	total    int
	success  int
	failure  int
	duration int
}

func (s *artifactCallMetricsStub) IncrementTotal() { s.total++ }

func (s *artifactCallMetricsStub) IncrementSuccess() { s.success++ }

func (s *artifactCallMetricsStub) IncrementFailure() { s.failure++ }

func (s *artifactCallMetricsStub) TrackDuration(time.Time) { s.duration++ }

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
