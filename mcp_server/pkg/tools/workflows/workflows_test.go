package workflows

import (
	"context"
	"fmt"
	"net/http"
	"strings"
	"testing"
	"time"

	"github.com/mark3labs/mcp-go/mcp"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/feature"
	workflowpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/plumber_w_f.workflow"
	projecthubpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/projecthub"
	rbacpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/rbac"
	repopb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/repository_integrator"
	statuspb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/status"
	userpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/user"
	support "github.com/semaphoreio/semaphore/mcp_server/test/support"

	"google.golang.org/genproto/googleapis/rpc/code"
	"google.golang.org/grpc"
	"google.golang.org/protobuf/types/known/timestamppb"
)

func TestListWorkflows_FeatureFlagDisabled(t *testing.T) {
	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"organization_id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
		"project_id":      "11111111-2222-3333-4444-555555555555",
	}}}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", "99999999-aaaa-bbbb-cccc-dddddddddddd")
	req.Header = header

	provider := &support.MockProvider{
		FeaturesService: support.FeatureClientStub{State: feature.Hidden},
		Timeout:         time.Second,
		WorkflowClient:  &workflowClientStub{},
		RBACClient:      newRBACStub("project.view"),
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

func TestListWorkflows(t *testing.T) {
	projectID := "11111111-2222-3333-4444-555555555555"
	client := &workflowClientStub{
		listResp: &workflowpb.ListKeysetResponse{
			Status: &statuspb.Status{Code: code.Code_OK},
			Workflows: []*workflowpb.WorkflowDetails{
				{
					WfId:           "wf-123",
					ProjectId:      projectID,
					BranchName:     "main",
					CommitSha:      "abc123",
					CreatedAt:      timestamppb.New(time.Unix(1700000000, 0)),
					TriggeredBy:    workflowpb.TriggeredBy_MANUAL_RUN,
					OrganizationId: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
				},
			},
			NextPageToken: "cursor",
		},
	}

	provider := &support.MockProvider{
		WorkflowClient: client,
		Timeout:        time.Second,
		RBACClient:     newRBACStub("project.view"),
	}

	handler := listHandler(provider)
	req := mcp.CallToolRequest{
		Params: mcp.CallToolParams{
			Arguments: map[string]any{
				"project_id":      projectID,
				"organization_id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
				"limit":           10,
			},
		},
	}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", "99999999-aaaa-bbbb-cccc-dddddddddddd")
	req.Header = header

	res, err := handler(context.Background(), req)
	if err != nil {
		toFail(t, "handler error: %v", err)
	}

	result, ok := res.StructuredContent.(listResult)
	if !ok {
		toFail(t, "unexpected structured content type: %T", res.StructuredContent)
	}

	if len(result.Workflows) != 1 {
		toFail(t, "expected 1 workflow, got %d", len(result.Workflows))
	}

	wf := result.Workflows[0]
	if wf.ID != "wf-123" || wf.ProjectID != projectID || wf.TriggeredBy != "manual_run" {
		toFail(t, "unexpected workflow summary: %+v", wf)
	}

	if result.NextCursor != "cursor" {
		toFail(t, "expected next cursor 'cursor', got %q", result.NextCursor)
	}

	if client.lastList == nil {
		toFail(t, "expected list request to be recorded")
	}
	if got := client.lastList.GetRequesterId(); got != "99999999-aaaa-bbbb-cccc-dddddddddddd" {
		toFail(t, "expected requester to default to user header, got %s", got)
	}

	if got := client.lastList.GetPageSize(); got != 10 {
		toFail(t, "expected page size 10, got %d", got)
	}
}

func TestListWorkflowsWithRequesterOverride(t *testing.T) {
	projectID := "11111111-2222-3333-4444-555555555555"
	requester := "deploy-bot"
	client := &workflowClientStub{
		listResp: &workflowpb.ListKeysetResponse{
			Status:    &statuspb.Status{Code: code.Code_OK},
			Workflows: []*workflowpb.WorkflowDetails{},
		},
	}
	userClient := &userClientStub{
		response: &userpb.User{Id: "00000000-1111-2222-3333-444444444444"},
	}

	provider := &support.MockProvider{
		WorkflowClient: client,
		UserClient:     userClient,
		Timeout:        time.Second,
		RBACClient:     newRBACStub("project.view"),
	}

	req := mcp.CallToolRequest{
		Params: mcp.CallToolParams{
			Arguments: map[string]any{
				"project_id":        projectID,
				"organization_id":   "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
				"my_workflows_only": false,
				"requester":         requester,
			},
		},
	}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", "99999999-aaaa-bbbb-cccc-dddddddddddd")
	req.Header = header

	_, err := listHandler(provider)(context.Background(), req)
	if err != nil {
		toFail(t, "handler error: %v", err)
	}

	if client.lastList == nil {
		toFail(t, "expected list request to be recorded")
	}
	if got := strings.TrimSpace(client.lastList.GetRequesterId()); got != "00000000-1111-2222-3333-444444444444" {
		toFail(t, "expected requester override to propagate, got %s", got)
	}
	if userClient.lastRequest == nil || userClient.lastRequest.GetProvider() == nil {
		toFail(t, "expected user lookup to be recorded")
	}
	if login := userClient.lastRequest.GetProvider().GetLogin(); login != requester {
		toFail(t, "expected user lookup login %s, got %s", requester, login)
	}
}

func TestListWorkflowsPermissionDenied(t *testing.T) {
	projectID := "11111111-2222-3333-4444-555555555555"
	client := &workflowClientStub{}
	rbac := newRBACStub()

	provider := &support.MockProvider{
		WorkflowClient: client,
		Timeout:        time.Second,
		RBACClient:     rbac,
	}

	req := mcp.CallToolRequest{
		Params: mcp.CallToolParams{
			Arguments: map[string]any{
				"project_id":      projectID,
				"organization_id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
			},
		},
	}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", "99999999-aaaa-bbbb-cccc-dddddddddddd")
	req.Header = header

	res, err := listHandler(provider)(context.Background(), req)
	if err != nil {
		toFail(t, "handler error: %v", err)
	}

	msg := requireErrorText(t, res)
	if !strings.Contains(msg, `Permission denied while accessing project`) {
		toFail(t, "expected permission denied message, got %q", msg)
	}
	if client.lastList != nil {
		toFail(t, "expected no workflow RPC call, got %+v", client.lastList)
	}
	if len(rbac.lastRequests) != 1 {
		toFail(t, "expected one RBAC request, got %d", len(rbac.lastRequests))
	}
}

func TestListWorkflowsRBACUnavailable(t *testing.T) {
	projectID := "11111111-2222-3333-4444-555555555555"
	client := &workflowClientStub{}

	provider := &support.MockProvider{
		WorkflowClient: client,
		Timeout:        time.Second,
	}

	req := mcp.CallToolRequest{
		Params: mcp.CallToolParams{
			Arguments: map[string]any{
				"project_id":      projectID,
				"organization_id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
			},
		},
	}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", "99999999-aaaa-bbbb-cccc-dddddddddddd")
	req.Header = header

	res, err := listHandler(provider)(context.Background(), req)
	if err != nil {
		toFail(t, "handler error: %v", err)
	}

	msg := requireErrorText(t, res)
	if !strings.Contains(msg, "Authorization service is not configured") {
		toFail(t, "expected RBAC unavailable message, got %q", msg)
	}
	if client.lastList != nil {
		toFail(t, "expected no workflow RPC call, got %+v", client.lastList)
	}
}

func TestListWorkflowsScopeMismatchOrganization(t *testing.T) {
	projectID := "11111111-2222-3333-4444-555555555555"
	client := &workflowClientStub{
		listResp: &workflowpb.ListKeysetResponse{
			Status: &statuspb.Status{Code: code.Code_OK},
			Workflows: []*workflowpb.WorkflowDetails{
				{
					WfId:           "wf-123",
					ProjectId:      projectID,
					OrganizationId: "bbbbbbbb-cccc-dddd-eeee-ffffffffffff",
				},
			},
		},
	}
	rbac := newRBACStub("project.view")

	provider := &support.MockProvider{
		WorkflowClient: client,
		Timeout:        time.Second,
		RBACClient:     rbac,
	}

	req := mcp.CallToolRequest{
		Params: mcp.CallToolParams{
			Arguments: map[string]any{
				"project_id":      projectID,
				"organization_id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
			},
		},
	}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", "99999999-aaaa-bbbb-cccc-dddddddddddd")
	req.Header = header

	res, err := listHandler(provider)(context.Background(), req)
	if err != nil {
		toFail(t, "handler error: %v", err)
	}

	msg := requireErrorText(t, res)
	if !strings.Contains(msg, "outside the authorized organization scope") {
		toFail(t, "expected organization scope mismatch message, got %q", msg)
	}
}

func TestListWorkflowsScopeMismatchProject(t *testing.T) {
	projectID := "11111111-2222-3333-4444-555555555555"
	client := &workflowClientStub{
		listResp: &workflowpb.ListKeysetResponse{
			Status: &statuspb.Status{Code: code.Code_OK},
			Workflows: []*workflowpb.WorkflowDetails{
				{
					WfId:           "wf-123",
					ProjectId:      "different-project",
					OrganizationId: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
				},
			},
		},
	}
	rbac := newRBACStub("project.view")

	provider := &support.MockProvider{
		WorkflowClient: client,
		Timeout:        time.Second,
		RBACClient:     rbac,
	}

	req := mcp.CallToolRequest{
		Params: mcp.CallToolParams{
			Arguments: map[string]any{
				"project_id":      projectID,
				"organization_id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
			},
		},
	}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", "99999999-aaaa-bbbb-cccc-dddddddddddd")
	req.Header = header

	res, err := listHandler(provider)(context.Background(), req)
	if err != nil {
		toFail(t, "handler error: %v", err)
	}

	msg := requireErrorText(t, res)
	if !strings.Contains(msg, "outside the authorized project scope") {
		toFail(t, "expected project scope mismatch message, got %q", msg)
	}
}

func TestRunWorkflowSuccess(t *testing.T) {
	orgID := "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
	projectID := "11111111-2222-3333-4444-555555555555"
	userID := "99999999-aaaa-bbbb-cccc-dddddddddddd"
	repo := &projecthubpb.Project_Spec_Repository{
		Owner:           "octo",
		Name:            "repo",
		PipelineFile:    ".semaphore/ci.yml",
		IntegrationType: repopb.IntegrationType_GITHUB_APP,
	}
	projectStub := &projectClientStub{response: newProjectDescribeResponse(orgID, projectID, repo)}
	workflowStub := &workflowClientStub{
		scheduleResp: &workflowpb.ScheduleResponse{
			Status: &statuspb.Status{Code: code.Code_OK},
			WfId:   "wf-001",
			PplId:  "ppl-001",
		},
	}
	provider := &support.MockProvider{
		WorkflowClient: workflowStub,
		ProjectClient:  projectStub,
		Timeout:        time.Second,
		RBACClient:     newRBACStub(projectRunPermission),
	}

	req := mcp.CallToolRequest{
		Params: mcp.CallToolParams{
			Arguments: map[string]any{
				"organization_id": orgID,
				"project_id":      projectID,
				"reference":       "refs/heads/feature/login",
				"commit_sha":      "abc1234",
				"parameters": map[string]any{
					"DEPLOY_ENV": "staging",
				},
			},
		},
	}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", userID)
	req.Header = header

	res, err := runHandler(provider)(context.Background(), req)
	if err != nil {
		toFail(t, "handler error: %v", err)
	}
	result, ok := res.StructuredContent.(runResult)
	if !ok {
		toFail(t, "unexpected structured content type: %T", res.StructuredContent)
	}
	if result.WorkflowID != "wf-001" || result.PipelineID != "ppl-001" {
		toFail(t, "unexpected run result: %+v", result)
	}

	reqMsg := workflowStub.lastSchedule
	if reqMsg == nil {
		toFail(t, "expected schedule request to be recorded")
	}
	if reqMsg.GetProjectId() != projectID || reqMsg.GetOrganizationId() != orgID {
		toFail(t, "unexpected schedule scope: %+v", reqMsg)
	}
	if reqMsg.GetDefinitionFile() != ".semaphore/ci.yml" {
		toFail(t, "expected pipeline file from project, got %s", reqMsg.GetDefinitionFile())
	}
	if reqMsg.GetRepo().GetBranchName() != "feature/login" {
		toFail(t, "unexpected branch name: %s", reqMsg.GetRepo().GetBranchName())
	}
	if reqMsg.GetRepo().GetCommitSha() != "abc1234" {
		toFail(t, "unexpected commit sha: %s", reqMsg.GetRepo().GetCommitSha())
	}
	if reqMsg.GetLabel() != "feature/login" {
		toFail(t, "expected label to match branch name, got %s", reqMsg.GetLabel())
	}
	if got := reqMsg.GetService(); got != workflowpb.ScheduleRequest_GIT_HUB {
		toFail(t, "unexpected service type: %v", got)
	}
	if len(reqMsg.GetEnvVars()) != 1 || reqMsg.GetEnvVars()[0].GetName() != "DEPLOY_ENV" {
		toFail(t, "unexpected env vars: %+v", reqMsg.GetEnvVars())
	}
}

func TestRunWorkflowFeatureDisabled(t *testing.T) {
	orgID := "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
	projectID := "11111111-2222-3333-4444-555555555555"
	provider := &support.MockProvider{
		WorkflowClient:  &workflowClientStub{},
		ProjectClient:   &projectClientStub{response: newProjectDescribeResponse(orgID, projectID, &projecthubpb.Project_Spec_Repository{})},
		Timeout:         time.Second,
		RBACClient:      newRBACStub(projectRunPermission),
		FeaturesService: support.FeatureClientStub{State: feature.Hidden},
	}
	req := mcp.CallToolRequest{
		Params: mcp.CallToolParams{Arguments: map[string]any{
			"organization_id": orgID,
			"project_id":      projectID,
			"reference":       "main",
		}},
	}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", "99999999-aaaa-bbbb-cccc-dddddddddddd")
	req.Header = header

	res, err := runHandler(provider)(context.Background(), req)
	if err != nil {
		toFail(t, "handler error: %v", err)
	}
	msg := requireErrorText(t, res)
	if !strings.Contains(strings.ToLower(msg), "disabled") {
		toFail(t, "expected feature disabled message, got %q", msg)
	}
}

func TestRunWorkflowInvalidParameters(t *testing.T) {
	orgID := "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
	projectID := "11111111-2222-3333-4444-555555555555"
	provider := &support.MockProvider{
		WorkflowClient: &workflowClientStub{},
		ProjectClient:  &projectClientStub{response: newProjectDescribeResponse(orgID, projectID, &projecthubpb.Project_Spec_Repository{})},
		Timeout:        time.Second,
		RBACClient:     newRBACStub(projectRunPermission),
	}
	req := mcp.CallToolRequest{
		Params: mcp.CallToolParams{Arguments: map[string]any{
			"organization_id": orgID,
			"project_id":      projectID,
			"reference":       "main",
			"parameters":      []string{"bad"},
		}},
	}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", "99999999-aaaa-bbbb-cccc-dddddddddddd")
	req.Header = header

	res, err := runHandler(provider)(context.Background(), req)
	if err != nil {
		toFail(t, "handler error: %v", err)
	}
	msg := requireErrorText(t, res)
	if !strings.Contains(strings.ToLower(msg), "parameters") {
		toFail(t, "expected parameters error, got %q", msg)
	}
}

func TestRunWorkflowPermissionDenied(t *testing.T) {
	orgID := "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
	projectID := "11111111-2222-3333-4444-555555555555"
	workflowStub := &workflowClientStub{}
	provider := &support.MockProvider{
		WorkflowClient: workflowStub,
		ProjectClient:  &projectClientStub{response: newProjectDescribeResponse(orgID, projectID, &projecthubpb.Project_Spec_Repository{})},
		Timeout:        time.Second,
		RBACClient:     newRBACStub(), // no permissions granted
	}
	req := mcp.CallToolRequest{
		Params: mcp.CallToolParams{Arguments: map[string]any{
			"organization_id": orgID,
			"project_id":      projectID,
			"reference":       "main",
		}},
	}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", "99999999-aaaa-bbbb-cccc-dddddddddddd")
	req.Header = header

	res, err := runHandler(provider)(context.Background(), req)
	if err != nil {
		toFail(t, "handler error: %v", err)
	}
	msg := requireErrorText(t, res)
	if !strings.Contains(msg, "Permission denied while accessing project") {
		toFail(t, "expected permission denied message, got %q", msg)
	}
	if workflowStub.lastSchedule != nil {
		toFail(t, "workflow schedule should not have been invoked when permission is missing")
	}
}

func TestRunWorkflowInvalidCommitSHA(t *testing.T) {
	orgID := "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
	projectID := "11111111-2222-3333-4444-555555555555"
	userID := "99999999-aaaa-bbbb-cccc-dddddddddddd"
	provider := &support.MockProvider{
		WorkflowClient: &workflowClientStub{},
		ProjectClient:  &projectClientStub{response: newProjectDescribeResponse(orgID, projectID, &projecthubpb.Project_Spec_Repository{})},
		Timeout:        time.Second,
		RBACClient:     newRBACStub(projectRunPermission),
	}

	testCases := []struct {
		name      string
		commitSHA string
		expectErr string
	}{
		{
			name:      "non-hex characters",
			commitSHA: "xyz1234",
			expectErr: "hexadecimal SHA",
		},
		{
			name:      "too long",
			commitSHA: "abc123" + strings.Repeat("0", 60),
			expectErr: "must not exceed 64 characters",
		},
		{
			name:      "too short",
			commitSHA: "abc123",
			expectErr: "hexadecimal SHA",
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			req := mcp.CallToolRequest{
				Params: mcp.CallToolParams{Arguments: map[string]any{
					"organization_id": orgID,
					"project_id":      projectID,
					"reference":       "main",
					"commit_sha":      tc.commitSHA,
				}},
			}
			header := http.Header{}
			header.Set("X-Semaphore-User-ID", userID)
			req.Header = header

			res, err := runHandler(provider)(context.Background(), req)
			if err != nil {
				toFail(t, "handler error: %v", err)
			}
			msg := requireErrorText(t, res)
			if !strings.Contains(msg, tc.expectErr) {
				toFail(t, "expected error containing %q, got %q", tc.expectErr, msg)
			}
		})
	}
}

func TestRunWorkflowInvalidPipelineFile(t *testing.T) {
	orgID := "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
	projectID := "11111111-2222-3333-4444-555555555555"
	userID := "99999999-aaaa-bbbb-cccc-dddddddddddd"
	provider := &support.MockProvider{
		WorkflowClient: &workflowClientStub{},
		ProjectClient:  &projectClientStub{response: newProjectDescribeResponse(orgID, projectID, &projecthubpb.Project_Spec_Repository{})},
		Timeout:        time.Second,
		RBACClient:     newRBACStub(projectRunPermission),
	}

	testCases := []struct {
		name         string
		pipelineFile string
		expectErr    string
	}{
		{
			name:         "path traversal",
			pipelineFile: "../../etc/passwd",
			expectErr:    "must not contain '..' sequences",
		},
		{
			name:         "absolute path",
			pipelineFile: "/etc/passwd",
			expectErr:    "must be a relative path",
		},
		{
			name:         "backslash",
			pipelineFile: "path\\to\\file",
			expectErr:    "must not contain backslashes",
		},
		{
			name:         "control characters",
			pipelineFile: "file\x00.yml",
			expectErr:    "contains control characters",
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			req := mcp.CallToolRequest{
				Params: mcp.CallToolParams{Arguments: map[string]any{
					"organization_id": orgID,
					"project_id":      projectID,
					"reference":       "main",
					"pipeline_file":   tc.pipelineFile,
				}},
			}
			header := http.Header{}
			header.Set("X-Semaphore-User-ID", userID)
			req.Header = header

			res, err := runHandler(provider)(context.Background(), req)
			if err != nil {
				toFail(t, "handler error: %v", err)
			}
			msg := requireErrorText(t, res)
			if !strings.Contains(msg, tc.expectErr) {
				toFail(t, "expected error containing %q, got %q", tc.expectErr, msg)
			}
		})
	}
}

func TestRunWorkflowProjectDescribeFailure(t *testing.T) {
	orgID := "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
	projectID := "11111111-2222-3333-4444-555555555555"
	userID := "99999999-aaaa-bbbb-cccc-dddddddddddd"
	provider := &support.MockProvider{
		WorkflowClient: &workflowClientStub{},
		ProjectClient:  &projectClientStub{err: fmt.Errorf("connection timeout")},
		Timeout:        time.Second,
		RBACClient:     newRBACStub(projectRunPermission),
	}

	req := mcp.CallToolRequest{
		Params: mcp.CallToolParams{Arguments: map[string]any{
			"organization_id": orgID,
			"project_id":      projectID,
			"reference":       "main",
		}},
	}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", userID)
	req.Header = header

	res, err := runHandler(provider)(context.Background(), req)
	if err != nil {
		toFail(t, "handler error: %v", err)
	}
	msg := requireErrorText(t, res)
	if !strings.Contains(msg, "Unable to load project details") {
		toFail(t, "expected project load error, got %q", msg)
	}
}

func TestRunWorkflowScheduleFailure(t *testing.T) {
	orgID := "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
	projectID := "11111111-2222-3333-4444-555555555555"
	userID := "99999999-aaaa-bbbb-cccc-dddddddddddd"
	repo := &projecthubpb.Project_Spec_Repository{
		Owner:           "octo",
		Name:            "repo",
		PipelineFile:    ".semaphore/ci.yml",
		IntegrationType: repopb.IntegrationType_GITHUB_APP,
	}
	provider := &support.MockProvider{
		WorkflowClient: &workflowClientStub{scheduleErr: fmt.Errorf("scheduler unavailable")},
		ProjectClient:  &projectClientStub{response: newProjectDescribeResponse(orgID, projectID, repo)},
		Timeout:        time.Second,
		RBACClient:     newRBACStub(projectRunPermission),
	}

	req := mcp.CallToolRequest{
		Params: mcp.CallToolParams{Arguments: map[string]any{
			"organization_id": orgID,
			"project_id":      projectID,
			"reference":       "main",
		}},
	}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", userID)
	req.Header = header

	res, err := runHandler(provider)(context.Background(), req)
	if err != nil {
		toFail(t, "handler error: %v", err)
	}
	msg := requireErrorText(t, res)
	if !strings.Contains(msg, "Workflow schedule failed") {
		toFail(t, "expected schedule failure error, got %q", msg)
	}
}

func TestRunWorkflowScopeMismatch(t *testing.T) {
	orgID := "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
	wrongOrgID := "bbbbbbbb-cccc-dddd-eeee-ffffffffffff"
	projectID := "11111111-2222-3333-4444-555555555555"
	userID := "99999999-aaaa-bbbb-cccc-dddddddddddd"
	repo := &projecthubpb.Project_Spec_Repository{
		Owner:           "octo",
		Name:            "repo",
		IntegrationType: repopb.IntegrationType_GITHUB_APP,
	}
	// Project response indicates it belongs to a different org
	response := newProjectDescribeResponse(wrongOrgID, projectID, repo)
	provider := &support.MockProvider{
		WorkflowClient: &workflowClientStub{},
		ProjectClient:  &projectClientStub{response: response},
		Timeout:        time.Second,
		RBACClient:     newRBACStub(projectRunPermission),
	}

	req := mcp.CallToolRequest{
		Params: mcp.CallToolParams{Arguments: map[string]any{
			"organization_id": orgID,
			"project_id":      projectID,
			"reference":       "main",
		}},
	}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", userID)
	req.Header = header

	res, err := runHandler(provider)(context.Background(), req)
	if err != nil {
		toFail(t, "handler error: %v", err)
	}
	msg := requireErrorText(t, res)
	if !strings.Contains(msg, "does not belong to organization") {
		toFail(t, "expected scope mismatch error, got %q", msg)
	}
}

func TestRunWorkflowMissingRepository(t *testing.T) {
	orgID := "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
	projectID := "11111111-2222-3333-4444-555555555555"
	userID := "99999999-aaaa-bbbb-cccc-dddddddddddd"
	// Project with nil repository
	response := &projecthubpb.DescribeResponse{
		Metadata: &projecthubpb.ResponseMeta{
			Status: &projecthubpb.ResponseMeta_Status{Code: projecthubpb.ResponseMeta_OK},
		},
		Project: &projecthubpb.Project{
			Metadata: &projecthubpb.Project_Metadata{Id: projectID, OrgId: orgID},
			Spec:     &projecthubpb.Project_Spec{Repository: nil},
		},
	}
	provider := &support.MockProvider{
		WorkflowClient: &workflowClientStub{},
		ProjectClient:  &projectClientStub{response: response},
		Timeout:        time.Second,
		RBACClient:     newRBACStub(projectRunPermission),
	}

	req := mcp.CallToolRequest{
		Params: mcp.CallToolParams{Arguments: map[string]any{
			"organization_id": orgID,
			"project_id":      projectID,
			"reference":       "main",
		}},
	}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", userID)
	req.Header = header

	res, err := runHandler(provider)(context.Background(), req)
	if err != nil {
		toFail(t, "handler error: %v", err)
	}
	msg := requireErrorText(t, res)
	if !strings.Contains(msg, "repository configuration is missing") {
		toFail(t, "expected missing repository error, got %q", msg)
	}
}

func TestRunWorkflowInvalidParameterNames(t *testing.T) {
	orgID := "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
	projectID := "11111111-2222-3333-4444-555555555555"
	userID := "99999999-aaaa-bbbb-cccc-dddddddddddd"
	provider := &support.MockProvider{
		WorkflowClient: &workflowClientStub{},
		ProjectClient:  &projectClientStub{response: newProjectDescribeResponse(orgID, projectID, &projecthubpb.Project_Spec_Repository{})},
		Timeout:        time.Second,
		RBACClient:     newRBACStub(projectRunPermission),
	}

	testCases := []struct {
		name       string
		parameters map[string]any
		expectErr  string
	}{
		{
			name:       "empty parameter name",
			parameters: map[string]any{"": "value"},
			expectErr:  "parameter names must not be empty",
		},
		{
			name:       "whitespace only",
			parameters: map[string]any{"  ": "value"},
			expectErr:  "parameter names must not be empty",
		},
		{
			name:       "starts with digit",
			parameters: map[string]any{"9VAR": "value"},
			expectErr:  "must start with a letter or underscore",
		},
		{
			name:       "contains special chars",
			parameters: map[string]any{"MY-VAR": "value"},
			expectErr:  "must start with a letter or underscore",
		},
		{
			name:       "contains space",
			parameters: map[string]any{"MY VAR": "value"},
			expectErr:  "must start with a letter or underscore",
		},
		{
			name:       "contains control chars",
			parameters: map[string]any{"VAR\x00NAME": "value"},
			expectErr:  "contains control characters",
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			req := mcp.CallToolRequest{
				Params: mcp.CallToolParams{Arguments: map[string]any{
					"organization_id": orgID,
					"project_id":      projectID,
					"reference":       "main",
					"parameters":      tc.parameters,
				}},
			}
			header := http.Header{}
			header.Set("X-Semaphore-User-ID", userID)
			req.Header = header

			res, err := runHandler(provider)(context.Background(), req)
			if err != nil {
				toFail(t, "handler error: %v", err)
			}
			msg := requireErrorText(t, res)
			if !strings.Contains(msg, tc.expectErr) {
				toFail(t, "expected error containing %q, got %q", tc.expectErr, msg)
			}
		})
	}
}

func TestRunWorkflowInvalidParameterValues(t *testing.T) {
	orgID := "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
	projectID := "11111111-2222-3333-4444-555555555555"
	userID := "99999999-aaaa-bbbb-cccc-dddddddddddd"
	provider := &support.MockProvider{
		WorkflowClient: &workflowClientStub{},
		ProjectClient:  &projectClientStub{response: newProjectDescribeResponse(orgID, projectID, &projecthubpb.Project_Spec_Repository{})},
		Timeout:        time.Second,
		RBACClient:     newRBACStub(projectRunPermission),
	}

	testCases := []struct {
		name       string
		parameters map[string]any
		expectErr  string
	}{
		{
			name:       "array value",
			parameters: map[string]any{"TAGS": []string{"tag1", "tag2"}},
			expectErr:  "must be strings, numbers, booleans, or null",
		},
		{
			name:       "nested object",
			parameters: map[string]any{"CONFIG": map[string]string{"key": "value"}},
			expectErr:  "must be strings, numbers, booleans, or null",
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			req := mcp.CallToolRequest{
				Params: mcp.CallToolParams{Arguments: map[string]any{
					"organization_id": orgID,
					"project_id":      projectID,
					"reference":       "main",
					"parameters":      tc.parameters,
				}},
			}
			header := http.Header{}
			header.Set("X-Semaphore-User-ID", userID)
			req.Header = header

			res, err := runHandler(provider)(context.Background(), req)
			if err != nil {
				toFail(t, "handler error: %v", err)
			}
			msg := requireErrorText(t, res)
			if !strings.Contains(msg, tc.expectErr) {
				toFail(t, "expected error containing %q, got %q", tc.expectErr, msg)
			}
		})
	}
}

func TestRunWorkflowUnsupportedIntegrationType(t *testing.T) {
	orgID := "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
	projectID := "11111111-2222-3333-4444-555555555555"
	userID := "99999999-aaaa-bbbb-cccc-dddddddddddd"
	repo := &projecthubpb.Project_Spec_Repository{
		Owner:           "octo",
		Name:            "repo",
		IntegrationType: repopb.IntegrationType(999), // unknown type
	}
	provider := &support.MockProvider{
		WorkflowClient: &workflowClientStub{},
		ProjectClient:  &projectClientStub{response: newProjectDescribeResponse(orgID, projectID, repo)},
		Timeout:        time.Second,
		RBACClient:     newRBACStub(projectRunPermission),
	}

	req := mcp.CallToolRequest{
		Params: mcp.CallToolParams{Arguments: map[string]any{
			"organization_id": orgID,
			"project_id":      projectID,
			"reference":       "main",
		}},
	}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", userID)
	req.Header = header

	res, err := runHandler(provider)(context.Background(), req)
	if err != nil {
		toFail(t, "handler error: %v", err)
	}
	msg := requireErrorText(t, res)
	if !strings.Contains(msg, "integration type is not supported") {
		toFail(t, "expected unsupported integration type error, got %q", msg)
	}
}

type workflowClientStub struct {
	workflowpb.WorkflowServiceClient
	listResp     *workflowpb.ListKeysetResponse
	listErr      error
	lastList     *workflowpb.ListKeysetRequest
	scheduleResp *workflowpb.ScheduleResponse
	scheduleErr  error
	lastSchedule *workflowpb.ScheduleRequest
}

type projectClientStub struct {
	projecthubpb.ProjectServiceClient
	response     *projecthubpb.DescribeResponse
	err          error
	lastDescribe *projecthubpb.DescribeRequest
}

func (s *projectClientStub) Describe(ctx context.Context, in *projecthubpb.DescribeRequest, opts ...grpc.CallOption) (*projecthubpb.DescribeResponse, error) {
	s.lastDescribe = in
	if s.err != nil {
		return nil, s.err
	}
	return s.response, nil
}

func newProjectDescribeResponse(orgID, projectID string, repo *projecthubpb.Project_Spec_Repository) *projecthubpb.DescribeResponse {
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

func (s *workflowClientStub) Schedule(ctx context.Context, in *workflowpb.ScheduleRequest, opts ...grpc.CallOption) (*workflowpb.ScheduleResponse, error) {
	s.lastSchedule = in
	if s.scheduleErr != nil {
		return nil, s.scheduleErr
	}
	if s.scheduleResp != nil {
		return s.scheduleResp, nil
	}
	return &workflowpb.ScheduleResponse{Status: &statuspb.Status{Code: code.Code_OK}}, nil
}

func (s *workflowClientStub) GetPath(context.Context, *workflowpb.GetPathRequest, ...grpc.CallOption) (*workflowpb.GetPathResponse, error) {
	panic("not implemented")
}

func (s *workflowClientStub) List(context.Context, *workflowpb.ListRequest, ...grpc.CallOption) (*workflowpb.ListResponse, error) {
	panic("not implemented")
}

func (s *workflowClientStub) ListKeyset(ctx context.Context, in *workflowpb.ListKeysetRequest, opts ...grpc.CallOption) (*workflowpb.ListKeysetResponse, error) {
	s.lastList = in
	if s.listErr != nil {
		return nil, s.listErr
	}
	return s.listResp, nil
}

type userClientStub struct {
	userpb.UserServiceClient
	response    *userpb.User
	err         error
	lastRequest *userpb.DescribeByRepositoryProviderRequest
}

func (u *userClientStub) DescribeByRepositoryProvider(ctx context.Context, in *userpb.DescribeByRepositoryProviderRequest, opts ...grpc.CallOption) (*userpb.User, error) {
	u.lastRequest = in
	if u.err != nil {
		return nil, u.err
	}
	if u.response == nil {
		u.response = &userpb.User{Id: "ffffffff-ffff-ffff-ffff-ffffffffffff"}
	}
	return u.response, nil
}

func (s *workflowClientStub) ListGrouped(context.Context, *workflowpb.ListGroupedRequest, ...grpc.CallOption) (*workflowpb.ListGroupedResponse, error) {
	panic("not implemented")
}

func (s *workflowClientStub) ListGroupedKS(context.Context, *workflowpb.ListGroupedKSRequest, ...grpc.CallOption) (*workflowpb.ListGroupedKSResponse, error) {
	panic("not implemented")
}

func (s *workflowClientStub) ListLatestWorkflows(context.Context, *workflowpb.ListLatestWorkflowsRequest, ...grpc.CallOption) (*workflowpb.ListLatestWorkflowsResponse, error) {
	panic("not implemented")
}

func (s *workflowClientStub) Describe(context.Context, *workflowpb.DescribeRequest, ...grpc.CallOption) (*workflowpb.DescribeResponse, error) {
	panic("not implemented")
}

func (s *workflowClientStub) DescribeMany(context.Context, *workflowpb.DescribeManyRequest, ...grpc.CallOption) (*workflowpb.DescribeManyResponse, error) {
	panic("not implemented")
}

func (s *workflowClientStub) Terminate(context.Context, *workflowpb.TerminateRequest, ...grpc.CallOption) (*workflowpb.TerminateResponse, error) {
	panic("not implemented")
}

func (s *workflowClientStub) ListLabels(context.Context, *workflowpb.ListLabelsRequest, ...grpc.CallOption) (*workflowpb.ListLabelsResponse, error) {
	panic("not implemented")
}

func (s *workflowClientStub) Reschedule(context.Context, *workflowpb.RescheduleRequest, ...grpc.CallOption) (*workflowpb.ScheduleResponse, error) {
	panic("not implemented")
}

func (s *workflowClientStub) GetProjectId(context.Context, *workflowpb.GetProjectIdRequest, ...grpc.CallOption) (*workflowpb.GetProjectIdResponse, error) {
	panic("not implemented")
}

func (s *workflowClientStub) Create(context.Context, *workflowpb.CreateRequest, ...grpc.CallOption) (*workflowpb.CreateResponse, error) {
	panic("not implemented")
}

func toFail(t *testing.T, format string, args ...any) {
	t.Helper()
	t.Fatalf(format, args...)
}
