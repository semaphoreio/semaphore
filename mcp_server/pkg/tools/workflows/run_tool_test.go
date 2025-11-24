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
	support "github.com/semaphoreio/semaphore/mcp_server/test/support"

	code "google.golang.org/genproto/googleapis/rpc/code"
)

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
	projectStub := &support.ProjectClientStub{Response: support.NewProjectDescribeResponse(orgID, projectID, repo)}
	workflowStub := &support.WorkflowClientStub{
		ScheduleResp: &workflowpb.ScheduleResponse{
			Status: &statuspb.Status{Code: code.Code_OK},
			WfId:   "wf-001",
			PplId:  "ppl-001",
		},
	}
	provider := &support.MockProvider{
		WorkflowClient: workflowStub,
		ProjectClient:  projectStub,
		Timeout:        time.Second,
		RBACClient:     support.NewRBACStub(projectRunPermission),
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

	reqMsg := workflowStub.LastSchedule
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
		WorkflowClient:  &support.WorkflowClientStub{},
		ProjectClient:   &support.ProjectClientStub{Response: support.NewProjectDescribeResponse(orgID, projectID, &projecthubpb.Project_Spec_Repository{})},
		Timeout:         time.Second,
		RBACClient:      support.NewRBACStub(projectRunPermission),
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
		WorkflowClient: &support.WorkflowClientStub{},
		ProjectClient:  &support.ProjectClientStub{Response: support.NewProjectDescribeResponse(orgID, projectID, &projecthubpb.Project_Spec_Repository{})},
		Timeout:        time.Second,
		RBACClient:     support.NewRBACStub(projectRunPermission),
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
	workflowStub := &support.WorkflowClientStub{}
	provider := &support.MockProvider{
		WorkflowClient: workflowStub,
		ProjectClient:  &support.ProjectClientStub{Response: support.NewProjectDescribeResponse(orgID, projectID, &projecthubpb.Project_Spec_Repository{})},
		Timeout:        time.Second,
		RBACClient:     support.NewRBACStub(), // no permissions granted
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
	if workflowStub.LastSchedule != nil {
		toFail(t, "workflow schedule should not have been invoked when permission is missing")
	}
}

func TestRunWorkflowInvalidCommitSHA(t *testing.T) {
	orgID := "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
	projectID := "11111111-2222-3333-4444-555555555555"
	userID := "99999999-aaaa-bbbb-cccc-dddddddddddd"
	provider := &support.MockProvider{
		WorkflowClient: &support.WorkflowClientStub{},
		ProjectClient:  &support.ProjectClientStub{Response: support.NewProjectDescribeResponse(orgID, projectID, &projecthubpb.Project_Spec_Repository{})},
		Timeout:        time.Second,
		RBACClient:     support.NewRBACStub(projectRunPermission),
	}

	req := mcp.CallToolRequest{
		Params: mcp.CallToolParams{Arguments: map[string]any{
			"organization_id": orgID,
			"project_id":      projectID,
			"reference":       "main",
			"commit_sha":      "INVALID",
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
	if !strings.Contains(msg, "commit_sha must be a hexadecimal SHA") {
		toFail(t, "expected invalid commit sha error, got %q", msg)
	}
}

func TestRunWorkflowInvalidPipelineFile(t *testing.T) {
	orgID := "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
	projectID := "11111111-2222-3333-4444-555555555555"
	userID := "99999999-aaaa-bbbb-cccc-dddddddddddd"
	provider := &support.MockProvider{
		WorkflowClient: &support.WorkflowClientStub{},
		ProjectClient:  &support.ProjectClientStub{Response: support.NewProjectDescribeResponse(orgID, projectID, &projecthubpb.Project_Spec_Repository{})},
		Timeout:        time.Second,
		RBACClient:     support.NewRBACStub(projectRunPermission),
	}

	req := mcp.CallToolRequest{
		Params: mcp.CallToolParams{Arguments: map[string]any{
			"organization_id": orgID,
			"project_id":      projectID,
			"reference":       "main",
			"pipeline_file":   "../outside.yml",
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
	if !strings.Contains(msg, "pipeline_file must not contain '..' sequences") {
		toFail(t, "expected invalid pipeline file error, got %q", msg)
	}
}

func TestRunWorkflowProjectDescribeFailure(t *testing.T) {
	orgID := "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
	projectID := "11111111-2222-3333-4444-555555555555"
	userID := "99999999-aaaa-bbbb-cccc-dddddddddddd"
	provider := &support.MockProvider{
		WorkflowClient: &support.WorkflowClientStub{},
		ProjectClient:  &support.ProjectClientStub{Err: fmt.Errorf("project describe failed")},
		Timeout:        time.Second,
		RBACClient:     support.NewRBACStub(projectRunPermission),
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
		WorkflowClient: &support.WorkflowClientStub{ScheduleErr: fmt.Errorf("scheduler unavailable")},
		ProjectClient:  &support.ProjectClientStub{Response: support.NewProjectDescribeResponse(orgID, projectID, repo)},
		Timeout:        time.Second,
		RBACClient:     support.NewRBACStub(projectRunPermission),
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
	response := support.NewProjectDescribeResponse(wrongOrgID, projectID, repo)
	provider := &support.MockProvider{
		WorkflowClient: &support.WorkflowClientStub{},
		ProjectClient:  &support.ProjectClientStub{Response: response},
		Timeout:        time.Second,
		RBACClient:     support.NewRBACStub(projectRunPermission),
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
		WorkflowClient: &support.WorkflowClientStub{},
		ProjectClient:  &support.ProjectClientStub{Response: response},
		Timeout:        time.Second,
		RBACClient:     support.NewRBACStub(projectRunPermission),
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
		WorkflowClient: &support.WorkflowClientStub{},
		ProjectClient:  &support.ProjectClientStub{Response: support.NewProjectDescribeResponse(orgID, projectID, &projecthubpb.Project_Spec_Repository{})},
		Timeout:        time.Second,
		RBACClient:     support.NewRBACStub(projectRunPermission),
	}

	testCases := []struct {
		name       string
		parameters map[string]any
		expectErr  string
	}{
		{name: "empty parameter name", parameters: map[string]any{"": "value"}, expectErr: "parameter names must not be empty"},
		{name: "whitespace only", parameters: map[string]any{"  ": "value"}, expectErr: "parameter names must not be empty"},
		{name: "starts with digit", parameters: map[string]any{"9VAR": "value"}, expectErr: "must start with a letter or underscore"},
		{name: "contains special chars", parameters: map[string]any{"MY-VAR": "value"}, expectErr: "must start with a letter or underscore"},
		{name: "contains space", parameters: map[string]any{"MY VAR": "value"}, expectErr: "must start with a letter or underscore"},
		{name: "contains control chars", parameters: map[string]any{"VAR\x00NAME": "value"}, expectErr: "contains control characters"},
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
		WorkflowClient: &support.WorkflowClientStub{},
		ProjectClient:  &support.ProjectClientStub{Response: support.NewProjectDescribeResponse(orgID, projectID, &projecthubpb.Project_Spec_Repository{})},
		Timeout:        time.Second,
		RBACClient:     support.NewRBACStub(projectRunPermission),
	}

	testCases := []struct {
		name       string
		parameters map[string]any
		expectErr  string
	}{
		{name: "array value", parameters: map[string]any{"TAGS": []string{"tag1", "tag2"}}, expectErr: "must be strings, numbers, booleans, or null"},
		{name: "nested object", parameters: map[string]any{"CONFIG": map[string]string{"key": "value"}}, expectErr: "must be strings, numbers, booleans, or null"},
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
		IntegrationType: repopb.IntegrationType(999),
	}
	provider := &support.MockProvider{
		WorkflowClient: &support.WorkflowClientStub{},
		ProjectClient:  &support.ProjectClientStub{Response: support.NewProjectDescribeResponse(orgID, projectID, repo)},
		Timeout:        time.Second,
		RBACClient:     support.NewRBACStub(projectRunPermission),
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

// Ensure RBAC stub implements the interface at compile time.
var _ rbacpb.RBACClient = (*support.RBACStub)(nil)
