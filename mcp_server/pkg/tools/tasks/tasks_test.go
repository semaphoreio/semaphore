package tasks

import (
	"context"
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
					Branch:         "main",
					PipelineFile:   ".semaphore/nightly.yml",
					Schedule:       "0 0 * * *",
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

func TestDescribeTask(t *testing.T) {
	taskID := "11111111-2222-3333-4444-555555555555"
	orgID := "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
	projectID := "66666666-7777-8888-9999-aaaaaaaaaaaa"

	client := &support.SchedulerClientStub{
		DescribeResp: &schedulerpb.DescribeResponse{
			Status: &statuspb.Status{Code: code.Code_OK},
			Periodic: &schedulerpb.Periodic{
				Id:             taskID,
				Name:           "Nightly Build",
				Description:    "Runs every night",
				ProjectId:      projectID,
				OrganizationId: orgID,
				Branch:         "main",
				PipelineFile:   ".semaphore/nightly.yml",
				Schedule:       "0 0 * * *",
				CreatedAt:      timestamppb.New(time.Unix(1700000000, 0)),
				UpdatedAt:      timestamppb.New(time.Unix(1700000000, 0)),
			},
			RecentTriggers: []*schedulerpb.Trigger{
				{
					TriggeredAt:  timestamppb.New(time.Unix(1700000000, 0)),
					WorkflowId:   "wf-456",
					Status:       schedulerpb.TriggerStatus_TRIGGER_STATUS_PASSED,
					Branch:       "main",
					PipelineFile: ".semaphore/nightly.yml",
				},
			},
		},
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
		RunNowResp: &schedulerpb.RunNowResponse{
			Status:       &statuspb.Status{Code: code.Code_OK},
			WorkflowId:   "bbbbbbbb-cccc-dddd-eeee-ffffffffffff",
			PeriodicId:   taskID,
			PeriodicName: "Nightly Build",
			Branch:       "main",
			PipelineFile: ".semaphore/nightly.yml",
			TriggeredAt:  timestamppb.New(time.Unix(1700000000, 0)),
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

// --- test helpers ---

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
