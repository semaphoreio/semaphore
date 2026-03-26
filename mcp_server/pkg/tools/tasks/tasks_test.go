package tasks

import (
	"context"
	"fmt"
	"net/http"
	"strings"
	"testing"
	"time"

	"github.com/mark3labs/mcp-go/mcp"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/feature"
	schedulerpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/periodic_scheduler"
	statuspb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/status"
	support "github.com/semaphoreio/semaphore/mcp_server/test/support"

	"google.golang.org/genproto/googleapis/rpc/code"
	"google.golang.org/protobuf/types/known/timestamppb"
)

func TestListTasks_FeatureFlagDisabled(t *testing.T) {
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
		SchedulerClient: &support.SchedulerClientStub{},
		RBACClient:      support.NewRBACStub("project.scheduler.view"),
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

func TestListTasks(t *testing.T) {
	projectID := "11111111-2222-3333-4444-555555555555"
	orgID := "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"

	client := &support.SchedulerClientStub{
		ListResp: &schedulerpb.ListKeysetResponse{
			Status: &statuspb.Status{Code: code.Code_OK},
			Periodics: []*schedulerpb.Periodic{
				{
					Id:             "task-123",
					Name:           "Nightly Build",
					Description:    "Runs every night",
					ProjectId:      projectID,
					OrganizationId: orgID,
					Reference:      "main",
					PipelineFile:   ".semaphore/nightly.yml",
					At:             "0 0 * * *",
					Paused:         false,
					Suspended:      false,
					UpdatedAt:      timestamppb.New(time.Unix(1700000000, 0)),
				},
			},
			NextPageToken: "cursor",
		},
	}

	provider := &support.MockProvider{
		SchedulerClient: client,
		Timeout:         time.Second,
		RBACClient:      support.NewRBACStub("project.scheduler.view"),
	}

	handler := listHandler(provider)
	req := mcp.CallToolRequest{
		Params: mcp.CallToolParams{
			Arguments: map[string]any{
				"project_id":      projectID,
				"organization_id": orgID,
				"limit":           10,
			},
		},
	}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", "99999999-aaaa-bbbb-cccc-dddddddddddd")
	req.Header = header

	res, err := handler(context.Background(), req)
	if err != nil {
		t.Fatalf("handler error: %v", err)
	}

	result, ok := res.StructuredContent.(listResult)
	if !ok {
		t.Fatalf("unexpected structured content type: %T", res.StructuredContent)
	}

	if len(result.Tasks) != 1 {
		t.Fatalf("expected 1 task, got %d", len(result.Tasks))
	}

	task := result.Tasks[0]
	if task.ID != "task-123" {
		t.Fatalf("expected task ID 'task-123', got %q", task.ID)
	}
	if task.Name != "Nightly Build" {
		t.Fatalf("expected task name 'Nightly Build', got %q", task.Name)
	}
	if task.Schedule != "0 0 * * *" {
		t.Fatalf("expected schedule '0 0 * * *', got %q", task.Schedule)
	}

	if result.NextCursor != "cursor" {
		t.Fatalf("expected next cursor 'cursor', got %q", result.NextCursor)
	}

	if client.LastList == nil {
		t.Fatal("expected list request to be recorded")
	}
	if client.LastList.GetPageSize() != 10 {
		t.Fatalf("expected page size 10, got %d", client.LastList.GetPageSize())
	}
}

func newDescribeResponse(taskID, projectID, orgID string) *schedulerpb.DescribeResponse {
	return &schedulerpb.DescribeResponse{
		Status: &statuspb.Status{Code: code.Code_OK},
		Periodic: &schedulerpb.Periodic{
			Id:             taskID,
			Name:           "Nightly Build",
			Description:    "Runs every night",
			ProjectId:      projectID,
			OrganizationId: orgID,
			Reference:      "main",
			PipelineFile:   ".semaphore/nightly.yml",
			At:             "0 0 * * *",
			InsertedAt:     timestamppb.New(time.Unix(1700000000, 0)),
			UpdatedAt:      timestamppb.New(time.Unix(1700000000, 0)),
		},
		Triggers: []*schedulerpb.Trigger{
			{
				TriggeredAt:         timestamppb.New(time.Unix(1700000000, 0)),
				ScheduledWorkflowId: "wf-456",
				SchedulingStatus:    "passed",
				Reference:           "main",
				PipelineFile:        ".semaphore/nightly.yml",
			},
		},
	}
}

func TestDescribeTask(t *testing.T) {
	taskID := "11111111-2222-3333-4444-555555555555"
	orgID := "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
	projectID := "66666666-7777-8888-9999-aaaaaaaaaaaa"

	client := &support.SchedulerClientStub{
		DescribeResp: newDescribeResponse(taskID, projectID, orgID),
	}

	provider := &support.MockProvider{
		SchedulerClient: client,
		Timeout:         time.Second,
		RBACClient:      support.NewRBACStub("project.scheduler.view"),
	}

	handler := describeHandler(provider)
	req := mcp.CallToolRequest{
		Params: mcp.CallToolParams{
			Arguments: map[string]any{
				"task_id":         taskID,
				"project_id":      projectID,
				"organization_id": orgID,
				"mode":            "detailed",
			},
		},
	}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", "99999999-aaaa-bbbb-cccc-dddddddddddd")
	req.Header = header

	res, err := handler(context.Background(), req)
	if err != nil {
		t.Fatalf("handler error: %v", err)
	}

	if res.IsError {
		msg := ""
		if len(res.Content) > 0 {
			if text, ok := res.Content[0].(mcp.TextContent); ok {
				msg = text.Text
			}
		}
		t.Fatalf("unexpected error result: %s", msg)
	}

	result, ok := res.StructuredContent.(describeResult)
	if !ok {
		t.Fatalf("unexpected structured content type: %T", res.StructuredContent)
	}

	if result.Task.ID != taskID {
		t.Fatalf("expected task ID %q, got %q", taskID, result.Task.ID)
	}
	if result.Task.Name != "Nightly Build" {
		t.Fatalf("expected task name 'Nightly Build', got %q", result.Task.Name)
	}

	if len(result.RecentTriggers) != 1 {
		t.Fatalf("expected 1 trigger, got %d", len(result.RecentTriggers))
	}

	if result.RecentTriggers[0].WorkflowID != "wf-456" {
		t.Fatalf("expected workflow ID 'wf-456', got %q", result.RecentTriggers[0].WorkflowID)
	}
}

func TestRunTask(t *testing.T) {
	taskID := "11111111-2222-3333-4444-555555555555"
	projectID := "66666666-7777-8888-9999-aaaaaaaaaaaa"
	orgID := "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"

	client := &support.SchedulerClientStub{
		DescribeResp: newDescribeResponse(taskID, projectID, orgID),
		RunNowResp: &schedulerpb.RunNowResponse{
			Status: &statuspb.Status{Code: code.Code_OK},
			Periodic: &schedulerpb.Periodic{
				Id:           taskID,
				Name:         "Nightly Build",
				Reference:    "main",
				PipelineFile: ".semaphore/nightly.yml",
			},
			Trigger: &schedulerpb.Trigger{
				ScheduledWorkflowId: "bbbbbbbb-cccc-dddd-eeee-ffffffffffff",
				TriggeredAt:         timestamppb.New(time.Unix(1700000000, 0)),
			},
		},
	}

	provider := &support.MockProvider{
		SchedulerClient: client,
		Timeout:         time.Second,
		FeaturesService: support.FeatureClientStub{State: feature.Enabled},
		RBACClient:      support.NewRBACStub("project.scheduler.run_manually"),
	}

	handler := runHandler(provider)
	req := mcp.CallToolRequest{
		Params: mcp.CallToolParams{
			Arguments: map[string]any{
				"task_id":         taskID,
				"project_id":      projectID,
				"organization_id": orgID,
			},
		},
	}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", "99999999-aaaa-bbbb-cccc-dddddddddddd")
	req.Header = header

	res, err := handler(context.Background(), req)
	if err != nil {
		t.Fatalf("handler error: %v", err)
	}

	if res.IsError {
		msg := ""
		if len(res.Content) > 0 {
			if text, ok := res.Content[0].(mcp.TextContent); ok {
				msg = text.Text
			}
		}
		t.Fatalf("unexpected error result: %s", msg)
	}

	result, ok := res.StructuredContent.(runResult)
	if !ok {
		t.Fatalf("unexpected structured content type: %T", res.StructuredContent)
	}

	if result.TaskID != taskID {
		t.Fatalf("expected task ID %q, got %q", taskID, result.TaskID)
	}
	if result.WorkflowID != "bbbbbbbb-cccc-dddd-eeee-ffffffffffff" {
		t.Fatalf("expected workflow ID 'bbbbbbbb-cccc-dddd-eeee-ffffffffffff', got %q", result.WorkflowID)
	}

	if client.LastRunNow == nil {
		t.Fatal("expected RunNow request to be recorded")
	}
	if client.LastRunNow.GetId() != taskID {
		t.Fatalf("expected task ID %q in request, got %q", taskID, client.LastRunNow.GetId())
	}
}

func TestRunTask_WriteFeatureDisabled(t *testing.T) {
	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"task_id":         "11111111-2222-3333-4444-555555555555",
		"project_id":      "66666666-7777-8888-9999-aaaaaaaaaaaa",
		"organization_id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
	}}}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", "99999999-aaaa-bbbb-cccc-dddddddddddd")
	req.Header = header

	provider := &support.MockProvider{
		FeaturesService: support.FeatureClientStub{State: feature.Hidden},
		Timeout:         time.Second,
		SchedulerClient: &support.SchedulerClientStub{},
		RBACClient:      support.NewRBACStub("project.scheduler.run_manually"),
	}

	res, err := runHandler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	msg := requireErrorText(t, res)
	if !strings.Contains(strings.ToLower(msg), "disabled") {
		t.Fatalf("expected disabled feature error, got %q", msg)
	}
}

func TestListTasks_MissingProjectID(t *testing.T) {
	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"organization_id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
	}}}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", "99999999-aaaa-bbbb-cccc-dddddddddddd")
	req.Header = header

	provider := &support.MockProvider{
		Timeout:         time.Second,
		SchedulerClient: &support.SchedulerClientStub{},
		RBACClient:      support.NewRBACStub("project.scheduler.view"),
	}

	res, err := listHandler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	msg := requireErrorText(t, res)
	if !strings.Contains(msg, "project_id") {
		t.Fatalf("expected error mentioning project_id, got %q", msg)
	}
}

func TestDescribeTask_InvalidTaskID(t *testing.T) {
	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"task_id":         "invalid-uuid",
		"project_id":      "66666666-7777-8888-9999-aaaaaaaaaaaa",
		"organization_id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
	}}}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", "99999999-aaaa-bbbb-cccc-dddddddddddd")
	req.Header = header

	provider := &support.MockProvider{
		Timeout:         time.Second,
		SchedulerClient: &support.SchedulerClientStub{},
		RBACClient:      support.NewRBACStub("project.scheduler.view"),
	}

	res, err := describeHandler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	msg := requireErrorText(t, res)
	if !strings.Contains(msg, "UUID") {
		t.Fatalf("expected UUID validation error, got %q", msg)
	}
}

func TestValidateParameterName(t *testing.T) {
	tests := []struct {
		name    string
		input   string
		wantErr bool
	}{
		// Valid names
		{name: "lowercase letter start", input: "myParam", wantErr: false},
		{name: "uppercase letter start", input: "MyParam", wantErr: false},
		{name: "underscore start", input: "_myParam", wantErr: false},
		{name: "single letter", input: "x", wantErr: false},
		{name: "single underscore", input: "_", wantErr: false},

		// Invalid: starts with number
		{name: "number start", input: "1param", wantErr: true},

		// Invalid: starts with special character
		{name: "hyphen start", input: "-param", wantErr: true},
		{name: "dot start", input: ".param", wantErr: true},

		// Invalid: starts with multi-byte UTF-8 character
		// These test the utf8.DecodeRuneInString fix - the old code using
		// rune(name[0]) would incorrectly interpret multi-byte characters
		{name: "emoji start", input: "🚀param", wantErr: true},
		{name: "chinese char start", input: "中param", wantErr: true},
		{name: "accented char start", input: "éparam", wantErr: true},

		// Invalid: control characters
		{name: "tab in name", input: "my\tparam", wantErr: true},
		{name: "newline in name", input: "my\nparam", wantErr: true},

		// Invalid: too long (over 128 characters)
		{name: "too long", input: strings.Repeat("a", 129), wantErr: true},

		// Valid: exactly 128 characters
		{name: "max length", input: strings.Repeat("a", 128), wantErr: false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := validateParameterName(tt.input)
			if (err != nil) != tt.wantErr {
				t.Errorf("validateParameterName(%q) error = %v, wantErr %v", tt.input, err, tt.wantErr)
			}
		})
	}
}

// --- #3: permission denied tests ---

func TestListTasks_PermissionDenied(t *testing.T) {
	client := &support.SchedulerClientStub{}
	provider := &support.MockProvider{
		SchedulerClient: client,
		Timeout:         time.Second,
		RBACClient:      support.NewRBACStub(), // no permissions
	}

	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"project_id":      "11111111-2222-3333-4444-555555555555",
		"organization_id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
	}}}
	req.Header = authHeader()

	res, err := listHandler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	msg := requireErrorText(t, res)
	if !strings.Contains(strings.ToLower(msg), "permission") {
		t.Fatalf("expected permission error, got %q", msg)
	}
	if client.LastList != nil {
		t.Fatal("expected ListKeyset RPC to NOT be called when permission is denied")
	}
}

func TestDescribeTask_PermissionDenied(t *testing.T) {
	client := &support.SchedulerClientStub{}
	provider := &support.MockProvider{
		SchedulerClient: client,
		Timeout:         time.Second,
		RBACClient:      support.NewRBACStub(), // no permissions
	}

	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"task_id":         "11111111-2222-3333-4444-555555555555",
		"project_id":      "66666666-7777-8888-9999-aaaaaaaaaaaa",
		"organization_id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
	}}}
	req.Header = authHeader()

	res, err := describeHandler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	msg := requireErrorText(t, res)
	if !strings.Contains(strings.ToLower(msg), "permission") {
		t.Fatalf("expected permission error, got %q", msg)
	}
	if client.LastDescribe != nil {
		t.Fatal("expected Describe RPC to NOT be called when permission is denied")
	}
}

func TestRunTask_PermissionDenied(t *testing.T) {
	client := &support.SchedulerClientStub{}
	provider := &support.MockProvider{
		SchedulerClient: client,
		Timeout:         time.Second,
		FeaturesService: support.FeatureClientStub{State: feature.Enabled},
		RBACClient:      support.NewRBACStub(), // no permissions
	}

	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"task_id":         "11111111-2222-3333-4444-555555555555",
		"project_id":      "66666666-7777-8888-9999-aaaaaaaaaaaa",
		"organization_id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
	}}}
	req.Header = authHeader()

	res, err := runHandler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	msg := requireErrorText(t, res)
	if !strings.Contains(strings.ToLower(msg), "permission") {
		t.Fatalf("expected permission error, got %q", msg)
	}
	if client.LastRunNow != nil {
		t.Fatal("expected RunNow RPC to NOT be called when permission is denied")
	}
}

// --- scope mismatch tests ---

func TestDescribeTask_OrgScopeMismatch(t *testing.T) {
	taskID := "11111111-2222-3333-4444-555555555555"
	orgID := "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
	projectID := "66666666-7777-8888-9999-aaaaaaaaaaaa"
	differentOrgID := "ffffffff-ffff-ffff-ffff-ffffffffffff"

	client := &support.SchedulerClientStub{
		DescribeResp: newDescribeResponse(taskID, projectID, differentOrgID),
	}
	provider := &support.MockProvider{
		SchedulerClient: client,
		Timeout:         time.Second,
		RBACClient:      support.NewRBACStub("project.scheduler.view"),
	}

	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"task_id":         taskID,
		"project_id":      projectID,
		"organization_id": orgID,
	}}}
	req.Header = authHeader()

	res, err := describeHandler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	msg := requireErrorText(t, res)
	if !strings.Contains(strings.ToLower(msg), "permission denied") {
		t.Fatalf("expected scope mismatch error, got %q", msg)
	}
	if !strings.Contains(strings.ToLower(msg), "organization") {
		t.Fatalf("expected organization scope error, got %q", msg)
	}
}

func TestDescribeTask_ProjectScopeMismatch(t *testing.T) {
	taskID := "11111111-2222-3333-4444-555555555555"
	orgID := "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
	projectID := "66666666-7777-8888-9999-aaaaaaaaaaaa"
	differentProjectID := "ffffffff-ffff-ffff-ffff-ffffffffffff"

	client := &support.SchedulerClientStub{
		DescribeResp: newDescribeResponse(taskID, differentProjectID, orgID),
	}
	provider := &support.MockProvider{
		SchedulerClient: client,
		Timeout:         time.Second,
		RBACClient:      support.NewRBACStub("project.scheduler.view"),
	}

	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"task_id":         taskID,
		"project_id":      projectID,
		"organization_id": orgID,
	}}}
	req.Header = authHeader()

	res, err := describeHandler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	msg := requireErrorText(t, res)
	if !strings.Contains(strings.ToLower(msg), "permission denied") {
		t.Fatalf("expected scope mismatch error, got %q", msg)
	}
	if !strings.Contains(strings.ToLower(msg), "project") {
		t.Fatalf("expected project scope error, got %q", msg)
	}
}

func TestRunTask_OrgScopeMismatch(t *testing.T) {
	taskID := "11111111-2222-3333-4444-555555555555"
	orgID := "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
	projectID := "66666666-7777-8888-9999-aaaaaaaaaaaa"
	differentOrgID := "ffffffff-ffff-ffff-ffff-ffffffffffff"

	client := &support.SchedulerClientStub{
		DescribeResp: newDescribeResponse(taskID, projectID, differentOrgID),
	}
	provider := &support.MockProvider{
		SchedulerClient: client,
		Timeout:         time.Second,
		FeaturesService: support.FeatureClientStub{State: feature.Enabled},
		RBACClient:      support.NewRBACStub("project.scheduler.run_manually"),
	}

	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"task_id":         taskID,
		"project_id":      projectID,
		"organization_id": orgID,
	}}}
	req.Header = authHeader()

	res, err := runHandler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	msg := requireErrorText(t, res)
	if !strings.Contains(strings.ToLower(msg), "permission denied") {
		t.Fatalf("expected scope mismatch error, got %q", msg)
	}
	if !strings.Contains(strings.ToLower(msg), "organization") {
		t.Fatalf("expected organization scope error, got %q", msg)
	}
	if client.LastRunNow != nil {
		t.Fatal("expected RunNow RPC to NOT be called when scope mismatches")
	}
}

func TestRunTask_ProjectScopeMismatch(t *testing.T) {
	taskID := "11111111-2222-3333-4444-555555555555"
	orgID := "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
	projectID := "66666666-7777-8888-9999-aaaaaaaaaaaa"
	differentProjectID := "ffffffff-ffff-ffff-ffff-ffffffffffff"

	client := &support.SchedulerClientStub{
		DescribeResp: newDescribeResponse(taskID, differentProjectID, orgID),
	}
	provider := &support.MockProvider{
		SchedulerClient: client,
		Timeout:         time.Second,
		FeaturesService: support.FeatureClientStub{State: feature.Enabled},
		RBACClient:      support.NewRBACStub("project.scheduler.run_manually"),
	}

	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"task_id":         taskID,
		"project_id":      projectID,
		"organization_id": orgID,
	}}}
	req.Header = authHeader()

	res, err := runHandler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	msg := requireErrorText(t, res)
	if !strings.Contains(strings.ToLower(msg), "permission denied") {
		t.Fatalf("expected scope mismatch error, got %q", msg)
	}
	if !strings.Contains(strings.ToLower(msg), "project") {
		t.Fatalf("expected project scope error, got %q", msg)
	}
	if client.LastRunNow != nil {
		t.Fatal("expected RunNow RPC to NOT be called when scope mismatches")
	}
}

// --- #4: RPC error tests ---

func TestListTasks_RPCError(t *testing.T) {
	client := &support.SchedulerClientStub{
		ListErr: fmt.Errorf("connection refused"),
	}
	provider := &support.MockProvider{
		SchedulerClient: client,
		Timeout:         time.Second,
		RBACClient:      support.NewRBACStub("project.scheduler.view"),
	}

	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"project_id":      "11111111-2222-3333-4444-555555555555",
		"organization_id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
	}}}
	req.Header = authHeader()

	res, err := listHandler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	msg := requireErrorText(t, res)
	if !strings.Contains(msg, "connection refused") {
		t.Fatalf("expected RPC error in message, got %q", msg)
	}
}

func TestDescribeTask_RPCError(t *testing.T) {
	client := &support.SchedulerClientStub{
		DescribeErr: fmt.Errorf("connection refused"),
	}
	provider := &support.MockProvider{
		SchedulerClient: client,
		Timeout:         time.Second,
		RBACClient:      support.NewRBACStub("project.scheduler.view"),
	}

	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"task_id":         "11111111-2222-3333-4444-555555555555",
		"project_id":      "66666666-7777-8888-9999-aaaaaaaaaaaa",
		"organization_id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
	}}}
	req.Header = authHeader()

	res, err := describeHandler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	msg := requireErrorText(t, res)
	if !strings.Contains(msg, "connection refused") {
		t.Fatalf("expected RPC error in message, got %q", msg)
	}
}

func TestRunTask_RPCError(t *testing.T) {
	taskID := "11111111-2222-3333-4444-555555555555"
	projectID := "66666666-7777-8888-9999-aaaaaaaaaaaa"
	orgID := "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"

	client := &support.SchedulerClientStub{
		DescribeResp: newDescribeResponse(taskID, projectID, orgID),
		RunNowErr:    fmt.Errorf("connection refused"),
	}
	provider := &support.MockProvider{
		SchedulerClient: client,
		Timeout:         time.Second,
		FeaturesService: support.FeatureClientStub{State: feature.Enabled},
		RBACClient:      support.NewRBACStub("project.scheduler.run_manually"),
	}

	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"task_id":         "11111111-2222-3333-4444-555555555555",
		"project_id":      "66666666-7777-8888-9999-aaaaaaaaaaaa",
		"organization_id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
	}}}
	req.Header = authHeader()

	res, err := runHandler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	msg := requireErrorText(t, res)
	if !strings.Contains(msg, "connection refused") {
		t.Fatalf("expected RPC error in message, got %q", msg)
	}
}

// --- #5: run with parameters test ---

func TestRunTask_WithParameters(t *testing.T) {
	taskID := "11111111-2222-3333-4444-555555555555"
	projectID := "66666666-7777-8888-9999-aaaaaaaaaaaa"
	orgID := "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"

	client := &support.SchedulerClientStub{
		DescribeResp: newDescribeResponse(taskID, projectID, orgID),
	}
	provider := &support.MockProvider{
		SchedulerClient: client,
		Timeout:         time.Second,
		FeaturesService: support.FeatureClientStub{State: feature.Enabled},
		RBACClient:      support.NewRBACStub("project.scheduler.run_manually"),
	}

	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"task_id":         taskID,
		"project_id":      projectID,
		"organization_id": orgID,
		"branch":          "develop",
		"pipeline_file":   ".semaphore/deploy.yml",
		"parameters":      map[string]any{"ENV": "staging", "VERBOSE": true},
	}}}
	req.Header = authHeader()

	res, err := runHandler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("handler error: %v", err)
	}
	if res.IsError {
		msg := ""
		if len(res.Content) > 0 {
			if text, ok := res.Content[0].(mcp.TextContent); ok {
				msg = text.Text
			}
		}
		t.Fatalf("unexpected error result: %s", msg)
	}

	if client.LastRunNow == nil {
		t.Fatal("expected RunNow request to be recorded")
	}
	if client.LastRunNow.GetReference() != "develop" {
		t.Fatalf("expected branch 'develop', got %q", client.LastRunNow.GetReference())
	}
	if client.LastRunNow.GetPipelineFile() != ".semaphore/deploy.yml" {
		t.Fatalf("expected pipeline file '.semaphore/deploy.yml', got %q", client.LastRunNow.GetPipelineFile())
	}

	params := client.LastRunNow.GetParameterValues()
	if len(params) != 2 {
		t.Fatalf("expected 2 parameters, got %d", len(params))
	}
	// Parameters are sorted alphabetically by buildParameters
	paramMap := make(map[string]string)
	for _, p := range params {
		paramMap[p.GetName()] = p.GetValue()
	}
	if paramMap["ENV"] != "staging" {
		t.Fatalf("expected ENV=staging, got %q", paramMap["ENV"])
	}
	if paramMap["VERBOSE"] != "true" {
		t.Fatalf("expected VERBOSE=true, got %q", paramMap["VERBOSE"])
	}
}

// --- #10: validatePipelineFile unit tests ---

func TestValidatePipelineFile(t *testing.T) {
	tests := []struct {
		name    string
		input   string
		wantErr bool
	}{
		{name: "empty is valid", input: "", wantErr: false},
		{name: "normal path", input: ".semaphore/deploy.yml", wantErr: false},
		{name: "nested path", input: "ci/pipelines/build.yml", wantErr: false},
		{name: "path traversal", input: "../etc/passwd", wantErr: true},
		{name: "path traversal mid", input: "ci/../../../etc/passwd", wantErr: true},
		{name: "absolute path", input: "/etc/passwd", wantErr: true},
		{name: "backslash", input: "ci\\build.yml", wantErr: true},
		{name: "control char tab", input: "ci/\tbuild.yml", wantErr: true},
		{name: "control char null", input: "ci/\x00build.yml", wantErr: true},
		{name: "control char del", input: "ci/\x7fbuild.yml", wantErr: true},
		{name: "too long", input: strings.Repeat("a", 513), wantErr: true},
		{name: "max length", input: strings.Repeat("a", 512), wantErr: false},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := validatePipelineFile(tt.input, "pipeline_file")
			if (err != nil) != tt.wantErr {
				t.Errorf("validatePipelineFile(%q) error = %v, wantErr %v", tt.input, err, tt.wantErr)
			}
		})
	}
}

// --- missing user ID header tests ---

func TestListTasks_MissingUserHeader(t *testing.T) {
	provider := &support.MockProvider{
		SchedulerClient: &support.SchedulerClientStub{},
		Timeout:         time.Second,
		RBACClient:      support.NewRBACStub("project.scheduler.view"),
	}

	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"project_id":      "11111111-2222-3333-4444-555555555555",
		"organization_id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
	}}}
	// No X-Semaphore-User-ID header set

	res, err := listHandler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	msg := requireErrorText(t, res)
	if !strings.Contains(strings.ToLower(msg), "x-semaphore-user-id") {
		t.Fatalf("expected error mentioning user ID header, got %q", msg)
	}
}

func TestDescribeTask_MissingUserHeader(t *testing.T) {
	provider := &support.MockProvider{
		SchedulerClient: &support.SchedulerClientStub{},
		Timeout:         time.Second,
		RBACClient:      support.NewRBACStub("project.scheduler.view"),
	}

	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"task_id":         "11111111-2222-3333-4444-555555555555",
		"project_id":      "66666666-7777-8888-9999-aaaaaaaaaaaa",
		"organization_id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
	}}}

	res, err := describeHandler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	msg := requireErrorText(t, res)
	if !strings.Contains(strings.ToLower(msg), "x-semaphore-user-id") {
		t.Fatalf("expected error mentioning user ID header, got %q", msg)
	}
}

func TestRunTask_MissingUserHeader(t *testing.T) {
	provider := &support.MockProvider{
		SchedulerClient: &support.SchedulerClientStub{},
		Timeout:         time.Second,
		FeaturesService: support.FeatureClientStub{State: feature.Enabled},
		RBACClient:      support.NewRBACStub("project.scheduler.run_manually"),
	}

	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"task_id":         "11111111-2222-3333-4444-555555555555",
		"project_id":      "66666666-7777-8888-9999-aaaaaaaaaaaa",
		"organization_id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
	}}}

	res, err := runHandler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	msg := requireErrorText(t, res)
	if !strings.Contains(strings.ToLower(msg), "x-semaphore-user-id") {
		t.Fatalf("expected error mentioning user ID header, got %q", msg)
	}
}

// --- run scope-check describe failure tests ---

func TestRunTask_ScopeCheckDescribeRPCError(t *testing.T) {
	provider := &support.MockProvider{
		SchedulerClient: &support.SchedulerClientStub{
			DescribeErr: fmt.Errorf("connection refused"),
		},
		Timeout:         time.Second,
		FeaturesService: support.FeatureClientStub{State: feature.Enabled},
		RBACClient:      support.NewRBACStub("project.scheduler.run_manually"),
	}

	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"task_id":         "11111111-2222-3333-4444-555555555555",
		"project_id":      "66666666-7777-8888-9999-aaaaaaaaaaaa",
		"organization_id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
	}}}
	req.Header = authHeader()

	res, err := runHandler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	msg := requireErrorText(t, res)
	if !strings.Contains(msg, "scope verification") {
		t.Fatalf("expected scope verification error, got %q", msg)
	}
	if provider.SchedulerClient.(*support.SchedulerClientStub).LastRunNow != nil {
		t.Fatal("expected RunNow RPC to NOT be called when scope-check Describe fails")
	}
}

func TestRunTask_ScopeCheckDescribeNonOKStatus(t *testing.T) {
	provider := &support.MockProvider{
		SchedulerClient: &support.SchedulerClientStub{
			DescribeResp: &schedulerpb.DescribeResponse{
				Status: &statuspb.Status{Code: code.Code_NOT_FOUND},
			},
		},
		Timeout:         time.Second,
		FeaturesService: support.FeatureClientStub{State: feature.Enabled},
		RBACClient:      support.NewRBACStub("project.scheduler.run_manually"),
	}

	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"task_id":         "11111111-2222-3333-4444-555555555555",
		"project_id":      "66666666-7777-8888-9999-aaaaaaaaaaaa",
		"organization_id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
	}}}
	req.Header = authHeader()

	res, err := runHandler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	msg := requireErrorText(t, res)
	if !strings.Contains(msg, "scope verification") {
		t.Fatalf("expected scope verification error, got %q", msg)
	}
}

func TestRunTask_ScopeCheckDescribeNilPeriodic(t *testing.T) {
	provider := &support.MockProvider{
		SchedulerClient: &support.SchedulerClientStub{
			DescribeResp: &schedulerpb.DescribeResponse{
				Status: &statuspb.Status{Code: code.Code_OK},
			},
		},
		Timeout:         time.Second,
		FeaturesService: support.FeatureClientStub{State: feature.Enabled},
		RBACClient:      support.NewRBACStub("project.scheduler.run_manually"),
	}

	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"task_id":         "11111111-2222-3333-4444-555555555555",
		"project_id":      "66666666-7777-8888-9999-aaaaaaaaaaaa",
		"organization_id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
	}}}
	req.Header = authHeader()

	res, err := runHandler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	msg := requireErrorText(t, res)
	if !strings.Contains(strings.ToLower(msg), "task not found") {
		t.Fatalf("expected task not found error, got %q", msg)
	}
}

// --- incomplete RunNow response test ---

func TestRunTask_IncompleteResponse(t *testing.T) {
	taskID := "11111111-2222-3333-4444-555555555555"
	projectID := "66666666-7777-8888-9999-aaaaaaaaaaaa"
	orgID := "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"

	client := &support.SchedulerClientStub{
		DescribeResp: newDescribeResponse(taskID, projectID, orgID),
		RunNowResp: &schedulerpb.RunNowResponse{
			Status:   &statuspb.Status{Code: code.Code_OK},
			Periodic: nil,
			Trigger:  nil,
		},
	}
	provider := &support.MockProvider{
		SchedulerClient: client,
		Timeout:         time.Second,
		FeaturesService: support.FeatureClientStub{State: feature.Enabled},
		RBACClient:      support.NewRBACStub("project.scheduler.run_manually"),
	}

	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"task_id":         taskID,
		"project_id":      projectID,
		"organization_id": orgID,
	}}}
	req.Header = authHeader()

	res, err := runHandler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	msg := requireErrorText(t, res)
	if !strings.Contains(strings.ToLower(msg), "incomplete response") {
		t.Fatalf("expected incomplete response error, got %q", msg)
	}
}

// --- nil scheduler client tests ---

func TestListTasks_NilSchedulerClient(t *testing.T) {
	provider := &support.MockProvider{
		SchedulerClient: nil,
		Timeout:         time.Second,
		RBACClient:      support.NewRBACStub("project.scheduler.view"),
	}

	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"project_id":      "11111111-2222-3333-4444-555555555555",
		"organization_id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
	}}}
	req.Header = authHeader()

	res, err := listHandler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	msg := requireErrorText(t, res)
	if !strings.Contains(strings.ToLower(msg), "scheduler") {
		t.Fatalf("expected scheduler not configured error, got %q", msg)
	}
}

func TestDescribeTask_NilSchedulerClient(t *testing.T) {
	provider := &support.MockProvider{
		SchedulerClient: nil,
		Timeout:         time.Second,
		RBACClient:      support.NewRBACStub("project.scheduler.view"),
	}

	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"task_id":         "11111111-2222-3333-4444-555555555555",
		"project_id":      "66666666-7777-8888-9999-aaaaaaaaaaaa",
		"organization_id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
	}}}
	req.Header = authHeader()

	res, err := describeHandler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	msg := requireErrorText(t, res)
	if !strings.Contains(strings.ToLower(msg), "scheduler") {
		t.Fatalf("expected scheduler not configured error, got %q", msg)
	}
}

func TestRunTask_NilSchedulerClient(t *testing.T) {
	provider := &support.MockProvider{
		SchedulerClient: nil,
		Timeout:         time.Second,
		FeaturesService: support.FeatureClientStub{State: feature.Enabled},
		RBACClient:      support.NewRBACStub("project.scheduler.run_manually"),
	}

	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"task_id":         "11111111-2222-3333-4444-555555555555",
		"project_id":      "66666666-7777-8888-9999-aaaaaaaaaaaa",
		"organization_id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
	}}}
	req.Header = authHeader()

	res, err := runHandler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	msg := requireErrorText(t, res)
	if !strings.Contains(strings.ToLower(msg), "scheduler") {
		t.Fatalf("expected scheduler not configured error, got %q", msg)
	}
}

// --- non-OK status tests ---

func TestDescribeTask_NonOKStatus(t *testing.T) {
	provider := &support.MockProvider{
		SchedulerClient: &support.SchedulerClientStub{
			DescribeResp: &schedulerpb.DescribeResponse{
				Status: &statuspb.Status{Code: code.Code_NOT_FOUND},
			},
		},
		Timeout:    time.Second,
		RBACClient: support.NewRBACStub("project.scheduler.view"),
	}

	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"task_id":         "11111111-2222-3333-4444-555555555555",
		"project_id":      "66666666-7777-8888-9999-aaaaaaaaaaaa",
		"organization_id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
	}}}
	req.Header = authHeader()

	res, err := describeHandler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	requireErrorText(t, res)
}

func TestListTasks_NonOKStatus(t *testing.T) {
	provider := &support.MockProvider{
		SchedulerClient: &support.SchedulerClientStub{
			ListResp: &schedulerpb.ListKeysetResponse{
				Status: &statuspb.Status{Code: code.Code_INTERNAL},
			},
		},
		Timeout:    time.Second,
		RBACClient: support.NewRBACStub("project.scheduler.view"),
	}

	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"project_id":      "11111111-2222-3333-4444-555555555555",
		"organization_id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
	}}}
	req.Header = authHeader()

	res, err := listHandler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	requireErrorText(t, res)
}

// --- test helpers ---

func authHeader() http.Header {
	h := http.Header{}
	h.Set("X-Semaphore-User-ID", "99999999-aaaa-bbbb-cccc-dddddddddddd")
	return h
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
