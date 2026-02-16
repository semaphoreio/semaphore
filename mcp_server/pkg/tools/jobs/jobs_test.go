package jobs

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/mark3labs/mcp-go/mcp"
	"github.com/mark3labs/mcp-go/server"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/feature"
	loghubpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/loghub"
	loghub2pb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/loghub2"
	orgpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/organization"
	rbacpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/rbac"
	responsepb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/response_status"
	jobpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/server_farm.job"
	support "github.com/semaphoreio/semaphore/mcp_server/test/support"

	"google.golang.org/grpc"
	"google.golang.org/protobuf/types/known/timestamppb"
)

const (
	testProjectUUID     = "33333333-3333-3333-3333-333333333333"
	selfHostedTestJobID = "88888888-7777-6666-5555-444444444444"
	selfHostedTestOrgID = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
	selfHostedTestUser  = "99999999-aaaa-bbbb-cccc-dddddddddddd"
)

// selfHostedTestEnv holds references to the stubs created by
// newSelfHostedTestEnv, allowing tests to inspect gRPC request details.
type selfHostedTestEnv struct {
	Handler       server.ToolHandlerFunc
	Loghub2Client *loghub2ClientStub
	OrgClient     *orgClientStub
}

// newSelfHostedTestEnv creates a standard self-hosted logs test environment
// with an httptest server, test log downloader, and all required stubs.
func newSelfHostedTestEnv(t *testing.T, httpHandler http.HandlerFunc) selfHostedTestEnv {
	t.Helper()
	ts := httptest.NewServer(httpHandler)
	t.Cleanup(ts.Close)

	resetLogCache()
	t.Cleanup(resetLogCache)

	testDownloader := func(ctx context.Context, url string) ([]string, error) {
		return downloadSelfHostedLogs(ctx, ts.URL)
	}

	loghub2Client := &loghub2ClientStub{
		resp: &loghub2pb.GenerateTokenResponse{Token: "token", Type: loghub2pb.TokenType_PULL},
	}
	orgClient := &orgClientStub{
		resp: &orgpb.DescribeResponse{
			Status: &responsepb.ResponseStatus{Code: responsepb.ResponseStatus_OK},
			Organization: &orgpb.Organization{
				OrgId:       selfHostedTestOrgID,
				OrgUsername: "acme",
			},
		},
	}

	provider := &support.MockProvider{
		JobClient: &jobClientStub{
			describeResp: &jobpb.DescribeResponse{
				Status: &responsepb.ResponseStatus{Code: responsepb.ResponseStatus_OK},
				Job: &jobpb.Job{
					Id:             selfHostedTestJobID,
					ProjectId:      testProjectUUID,
					OrganizationId: selfHostedTestOrgID,
					SelfHosted:     true,
				},
			},
		},
		Loghub2Client:      loghub2Client,
		OrganizationClient: orgClient,
		RBACClient:         newRBACStub("project.view"),
		Timeout:            time.Second,
	}

	return selfHostedTestEnv{
		Handler:       logsHandler(provider, testDownloader),
		Loghub2Client: loghub2Client,
		OrgClient:     orgClient,
	}
}

// callLogsHandler invokes the handler with the given arguments and a standard
// test user header, returning both the raw result and the typed logsResult.
func callLogsHandler(t *testing.T, handler server.ToolHandlerFunc, args map[string]any) (*mcp.CallToolResult, logsResult) {
	t.Helper()
	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: args}}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", selfHostedTestUser)
	req.Header = header

	res, err := handler(context.Background(), req)
	if err != nil {
		t.Fatalf("handler error: %v", err)
	}

	result, ok := res.StructuredContent.(logsResult)
	if !ok {
		t.Fatalf("unexpected structured content type: %T", res.StructuredContent)
	}

	return res, result
}

func TestDescribeJob_FeatureFlagDisabled(t *testing.T) {
	orgID := "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"organization_id": orgID,
		"job_id":          "11111111-2222-3333-4444-555555555555",
	}}}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", "99999999-aaaa-bbbb-cccc-dddddddddddd")
	req.Header = header

	provider := &support.MockProvider{
		FeaturesService: support.FeatureClientStub{State: feature.Hidden},
		Timeout:         time.Second,
	}

	res, err := describeHandler(provider)(context.Background(), req)
	if err != nil {
		toFail(t, "unexpected error: %v", err)
	}

	msg := requireErrorText(t, res)
	if !strings.Contains(strings.ToLower(msg), "disabled") {
		toFail(t, "expected disabled feature error, got %q", msg)
	}
}

func TestLogsHandler_FeatureFlagDisabled(t *testing.T) {
	orgID := "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"job_id": "11111111-2222-3333-4444-555555555555",
	}}}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", "99999999-aaaa-bbbb-cccc-dddddddddddd")
	req.Header = header

	provider := &support.MockProvider{
		FeaturesService: support.FeatureClientStub{State: feature.Hidden},
		Timeout:         time.Second,
		LoghubClient:    &loghubClientStub{},
		Loghub2Client:   &loghub2ClientStub{},
		JobClient: &jobClientStub{
			describeResp: &jobpb.DescribeResponse{
				Status: &responsepb.ResponseStatus{Code: responsepb.ResponseStatus_OK},
				Job: &jobpb.Job{
					Id:             "11111111-2222-3333-4444-555555555555",
					ProjectId:      testProjectUUID,
					OrganizationId: orgID,
				},
			},
		},
	}

	res, err := logsHandler(provider, downloadSelfHostedLogs)(context.Background(), req)
	if err != nil {
		toFail(t, "unexpected error: %v", err)
	}

	msg := requireErrorText(t, res)
	if !strings.Contains(strings.ToLower(msg), "disabled") {
		toFail(t, "expected disabled feature error, got %q", msg)
	}
}

func TestDescribeJob(t *testing.T) {
	jobID := "11111111-2222-3333-4444-555555555555"
	orgID := "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
	client := &jobClientStub{
		describeResp: &jobpb.DescribeResponse{
			Status: &responsepb.ResponseStatus{Code: responsepb.ResponseStatus_OK},
			Job: &jobpb.Job{
				Id:             jobID,
				Name:           "Build",
				PplId:          "ppl-1",
				ProjectId:      testProjectUUID,
				OrganizationId: orgID,
				FailureReason:  "",
				Timeline: &jobpb.Job_Timeline{
					CreatedAt: timestamppb.New(time.Unix(1700000000, 0)),
				},
			},
		},
	}

	provider := &support.MockProvider{JobClient: client, Timeout: time.Second, RBACClient: newRBACStub("project.view", "organization.view")}
	handler := describeHandler(provider)
	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"organization_id": orgID,
		"job_id":          jobID,
	}}}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", "99999999-aaaa-bbbb-cccc-dddddddddddd")
	req.Header = header

	res, err := handler(context.Background(), req)
	if err != nil {
		toFail(t, "handler error: %v", err)
	}

	result, ok := res.StructuredContent.(jobSummary)
	if !ok {
		toFail(t, "unexpected structured content type: %T", res.StructuredContent)
	}

	if result.ID != jobID || result.PipelineID != "ppl-1" {
		toFail(t, "unexpected job summary: %+v", result)
	}
}

func TestDescribeJobPermissionDenied(t *testing.T) {
	jobID := "11111111-2222-3333-4444-555555555555"
	orgID := "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
	client := &jobClientStub{
		describeResp: &jobpb.DescribeResponse{
			Status: &responsepb.ResponseStatus{Code: responsepb.ResponseStatus_OK},
			Job: &jobpb.Job{
				Id:             jobID,
				PplId:          "ppl-1",
				ProjectId:      testProjectUUID,
				OrganizationId: orgID,
			},
		},
	}
	rbac := newRBACStub("organization.view")
	provider := &support.MockProvider{JobClient: client, Timeout: time.Second, RBACClient: rbac}

	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"organization_id": orgID,
		"job_id":          jobID,
	}}}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", "99999999-aaaa-bbbb-cccc-dddddddddddd")
	req.Header = header

	res, err := describeHandler(provider)(context.Background(), req)
	if err != nil {
		toFail(t, "handler error: %v", err)
	}

	msg := requireErrorText(t, res)
	if !strings.Contains(msg, `Permission denied while accessing project `+testProjectUUID) {
		toFail(t, "expected project denial message, got %q", msg)
	}
	if len(rbac.lastRequests) != 1 {
		toFail(t, "expected one RBAC request, got %d", len(rbac.lastRequests))
	}
	if got := rbac.lastRequests[0].GetProjectId(); got != testProjectUUID {
		toFail(t, "expected RBAC project %s, got %s", testProjectUUID, got)
	}
	if got := rbac.lastRequests[0].GetOrgId(); got != orgID {
		toFail(t, "expected RBAC org %s, got %s", orgID, got)
	}
}

func TestDescribeJobRBACUnavailable(t *testing.T) {
	jobID := "11111111-2222-3333-4444-555555555555"
	orgID := "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
	client := &jobClientStub{
		describeResp: &jobpb.DescribeResponse{
			Status: &responsepb.ResponseStatus{Code: responsepb.ResponseStatus_OK},
			Job: &jobpb.Job{
				Id:             jobID,
				PplId:          "ppl-1",
				ProjectId:      testProjectUUID,
				OrganizationId: orgID,
			},
		},
	}

	provider := &support.MockProvider{JobClient: client, Timeout: time.Second}
	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"organization_id": orgID,
		"job_id":          jobID,
	}}}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", "99999999-aaaa-bbbb-cccc-dddddddddddd")
	req.Header = header

	res, err := describeHandler(provider)(context.Background(), req)
	if err != nil {
		toFail(t, "handler error: %v", err)
	}

	msg := requireErrorText(t, res)
	if !strings.Contains(msg, "Authorization service is not configured") {
		toFail(t, "expected RBAC unavailable message, got %q", msg)
	}
}

func TestDescribeJobScopeMismatchOrganization(t *testing.T) {
	jobID := "11111111-2222-3333-4444-555555555555"
	orgID := "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
	client := &jobClientStub{
		describeResp: &jobpb.DescribeResponse{
			Status: &responsepb.ResponseStatus{Code: responsepb.ResponseStatus_OK},
			Job: &jobpb.Job{
				Id:             jobID,
				PplId:          "ppl-1",
				ProjectId:      testProjectUUID,
				OrganizationId: "bbbbbbbb-cccc-dddd-eeee-ffffffffffff",
			},
		},
	}
	rbac := newRBACStub("project.view")
	provider := &support.MockProvider{JobClient: client, Timeout: time.Second, RBACClient: rbac}

	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"organization_id": orgID,
		"job_id":          jobID,
	}}}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", "99999999-aaaa-bbbb-cccc-dddddddddddd")
	req.Header = header

	res, err := describeHandler(provider)(context.Background(), req)
	if err != nil {
		toFail(t, "handler error: %v", err)
	}

	msg := requireErrorText(t, res)
	if !strings.Contains(msg, "outside the authorized organization scope") {
		toFail(t, "expected organization scope mismatch message, got %q", msg)
	}
	if len(rbac.lastRequests) != 0 {
		toFail(t, "expected no RBAC calls, got %d", len(rbac.lastRequests))
	}
}

func TestDescribeJobScopeMismatchMissingProject(t *testing.T) {
	jobID := "11111111-2222-3333-4444-555555555555"
	orgID := "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
	client := &jobClientStub{
		describeResp: &jobpb.DescribeResponse{
			Status: &responsepb.ResponseStatus{Code: responsepb.ResponseStatus_OK},
			Job: &jobpb.Job{
				Id:             jobID,
				PplId:          "ppl-1",
				ProjectId:      "",
				OrganizationId: orgID,
			},
		},
	}
	rbac := newRBACStub("project.view")
	provider := &support.MockProvider{JobClient: client, Timeout: time.Second, RBACClient: rbac}

	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"organization_id": orgID,
		"job_id":          jobID,
	}}}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", "99999999-aaaa-bbbb-cccc-dddddddddddd")
	req.Header = header

	res, err := describeHandler(provider)(context.Background(), req)
	if err != nil {
		toFail(t, "handler error: %v", err)
	}

	msg := requireErrorText(t, res)
	if !strings.Contains(msg, "outside the authorized project scope") {
		toFail(t, "expected project scope mismatch message, got %q", msg)
	}
	if len(rbac.lastRequests) != 0 {
		toFail(t, "expected no RBAC calls, got %d", len(rbac.lastRequests))
	}
}

func TestFetchHostedLogsPagination(t *testing.T) {
	const orgID = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
	const jobID = "99999999-aaaa-bbbb-cccc-dddddddddddd"

	jobClient := &jobClientStub{
		describeResp: &jobpb.DescribeResponse{
			Status: &responsepb.ResponseStatus{Code: responsepb.ResponseStatus_OK},
			Job: &jobpb.Job{
				Id:             jobID,
				ProjectId:      testProjectUUID,
				OrganizationId: orgID,
				SelfHosted:     false,
			},
		},
	}

	makeEvents := func(start, end int) []string {
		events := make([]string, end-start)
		for i := start; i < end; i++ {
			events[i-start] = fmt.Sprintf("line-%d", i)
		}
		return events
	}

	testCases := []struct {
		name           string
		cursor         string
		events         []string
		expectedStart  int
		expectedLen    int
		expectedFirst  string
		expectedLast   string
		expectedCursor string
		truncated      bool
	}{
		{
			name:           "initialRequestTruncatesToNewestLines",
			cursor:         "",
			events:         makeEvents(0, 500),
			expectedStart:  500 - maxLogPreviewLines,
			expectedLen:    maxLogPreviewLines,
			expectedFirst:  fmt.Sprintf("line-%d", 500-maxLogPreviewLines),
			expectedLast:   "line-499",
			expectedCursor: fmt.Sprintf("%d", 500-(2*maxLogPreviewLines)),
			truncated:      true,
		},
		{
			name:           "initialRequestShortLog",
			cursor:         "",
			events:         makeEvents(0, 100),
			expectedStart:  0,
			expectedLen:    100,
			expectedFirst:  "line-0",
			expectedLast:   "line-99",
			expectedCursor: "",
			truncated:      false,
		},
		{
			name:           "cursorInMiddleReturnsOlderChunk",
			cursor:         "150",
			events:         makeEvents(150, 500),
			expectedStart:  150,
			expectedLen:    maxLogPreviewLines,
			expectedFirst:  "line-150",
			expectedLast:   "line-349",
			expectedCursor: "0",
			truncated:      true,
		},
		{
			name:           "cursorAtBeginningHasNoFurtherPages",
			cursor:         "0",
			events:         makeEvents(0, 500),
			expectedStart:  0,
			expectedLen:    maxLogPreviewLines,
			expectedFirst:  "line-0",
			expectedLast:   "line-199",
			expectedCursor: "",
			truncated:      true,
		},
		{
			name:           "cursorBeyondEndReturnsEmptyPreview",
			cursor:         "9999",
			events:         []string{},
			expectedStart:  9999,
			expectedLen:    0,
			expectedCursor: "9799",
			truncated:      true,
		},
	}

	for _, tc := range testCases {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			loghubClient := &loghubClientStub{
				resp: &loghubpb.GetLogEventsResponse{
					Status: &responsepb.ResponseStatus{Code: responsepb.ResponseStatus_OK},
					Events: tc.events,
					Final:  false,
				},
			}

			provider := &support.MockProvider{
				JobClient:    jobClient,
				LoghubClient: loghubClient,
				RBACClient:   newRBACStub("project.view"),
				Timeout:      time.Second,
			}

			handler := logsHandler(provider, downloadSelfHostedLogs)
			args := map[string]any{
				"job_id": jobID,
			}
			if tc.cursor != "" {
				args["cursor"] = tc.cursor
			}
			req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: args}}
			header := http.Header{}
			header.Set("X-Semaphore-User-ID", "99999999-aaaa-bbbb-cccc-dddddddddddd")
			req.Header = header

			res, err := handler(context.Background(), req)
			if err != nil {
				toFail(t, "handler error: %v", err)
			}

			result, ok := res.StructuredContent.(logsResult)
			if !ok {
				toFail(t, "unexpected structured content type: %T", res.StructuredContent)
			}

			if result.StartLine != tc.expectedStart {
				toFail(t, "expected start line %d, got %d", tc.expectedStart, result.StartLine)
			}
			if len(result.Preview) != tc.expectedLen {
				toFail(t, "expected preview length %d, got %d", tc.expectedLen, len(result.Preview))
			}
			if tc.expectedLen > 0 {
				if got := result.Preview[0]; got != tc.expectedFirst {
					toFail(t, "unexpected first preview line: %s", got)
				}
				if got := result.Preview[len(result.Preview)-1]; got != tc.expectedLast {
					toFail(t, "unexpected last preview line: %s", got)
				}
			}
			if result.NextCursor != tc.expectedCursor {
				toFail(t, "expected next cursor %q, got %q", tc.expectedCursor, result.NextCursor)
			}
			if result.PreviewTruncated != tc.truncated {
				toFail(t, "expected truncated=%v, got %v", tc.truncated, result.PreviewTruncated)
			}
		})
	}
}

func TestFetchSelfHostedLogs(t *testing.T) {
	env := newSelfHostedTestEnv(t, func(w http.ResponseWriter, r *http.Request) {
		resp := logResponse{
			Events: []logEvent{
				{Output: "hello from self-hosted\n"},
				{Output: "build succeeded\n"},
			},
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(resp)
	})

	_, result := callLogsHandler(t, env.Handler, map[string]any{"job_id": selfHostedTestJobID})

	if result.Source != loghub2Source || result.Token != "token" || result.TokenTtlSeconds != loghub2TokenDuration {
		toFail(t, "unexpected loghub2 response: %+v", result)
	}

	expectedURL := fmt.Sprintf("https://acme.semaphoreci.com/api/v1/logs/%s?jwt=token", selfHostedTestJobID)
	if result.LogsURL != expectedURL {
		toFail(t, "expected logs URL %q, got %q", expectedURL, result.LogsURL)
	}

	if len(result.Preview) != 2 {
		toFail(t, "expected 2 preview lines, got %d: %v", len(result.Preview), result.Preview)
	}
	if result.Preview[0] != "hello from self-hosted" || result.Preview[1] != "build succeeded" {
		toFail(t, "unexpected preview lines: %v", result.Preview)
	}

	if env.Loghub2Client.lastRequest == nil || env.Loghub2Client.lastRequest.GetJobId() != selfHostedTestJobID {
		toFail(t, "unexpected loghub2 request: %+v", env.Loghub2Client.lastRequest)
	}
	if env.OrgClient.lastRequest == nil || env.OrgClient.lastRequest.GetOrgId() != selfHostedTestOrgID {
		toFail(t, "unexpected org describe request: %+v", env.OrgClient.lastRequest)
	}
}

func TestSelfHostedLogsDownloadFailureFallback(t *testing.T) {
	env := newSelfHostedTestEnv(t, func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
	})

	_, result := callLogsHandler(t, env.Handler, map[string]any{"job_id": selfHostedTestJobID})

	if result.Token != "token" {
		toFail(t, "expected token in fallback, got %q", result.Token)
	}
	if len(result.Preview) != 0 {
		toFail(t, "expected no preview lines in fallback, got %d", len(result.Preview))
	}

	expectedURL := fmt.Sprintf("https://acme.semaphoreci.com/api/v1/logs/%s?jwt=token", selfHostedTestJobID)
	if result.LogsURL != expectedURL {
		toFail(t, "expected logs URL %q, got %q", expectedURL, result.LogsURL)
	}
}

func TestSelfHostedLogsEmptyDownloadFallback(t *testing.T) {
	env := newSelfHostedTestEnv(t, func(w http.ResponseWriter, r *http.Request) {
		resp := logResponse{Events: []logEvent{}}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(resp)
	})

	res, result := callLogsHandler(t, env.Handler, map[string]any{"job_id": selfHostedTestJobID})

	if len(result.Preview) != 0 {
		toFail(t, "expected no preview lines for empty events, got %d", len(result.Preview))
	}
	if result.Token != "token" {
		toFail(t, "expected token in fallback, got %q", result.Token)
	}
	if result.LogsURL == "" {
		toFail(t, "expected logs URL in fallback")
	}

	text, ok := res.Content[0].(mcp.TextContent)
	if !ok {
		toFail(t, "expected text content, got %T", res.Content[0])
	}
	if !strings.Contains(text.Text, "short-lived token") {
		toFail(t, "expected fallback markdown with token instructions, got %q", text.Text)
	}
}

func TestSelfHostedLogsPagination(t *testing.T) {
	makeLogEvents := func(n int) []logEvent {
		var output strings.Builder
		for i := 0; i < n; i++ {
			fmt.Fprintf(&output, "line-%d\n", i)
		}
		return []logEvent{{Output: output.String()}}
	}

	testCases := []struct {
		name           string
		cursor         string
		lineCount      int
		expectedStart  int
		expectedLen    int
		expectedFirst  string
		expectedLast   string
		expectedCursor string
		truncated      bool
	}{
		{
			name:           "initialRequestTruncatesToNewestLines",
			cursor:         "",
			lineCount:      500,
			expectedStart:  500 - maxLogPreviewLines,
			expectedLen:    maxLogPreviewLines,
			expectedFirst:  fmt.Sprintf("line-%d", 500-maxLogPreviewLines),
			expectedLast:   "line-499",
			expectedCursor: fmt.Sprintf("%d", 500-(2*maxLogPreviewLines)),
			truncated:      true,
		},
		{
			name:          "initialRequestShortLog",
			cursor:        "",
			lineCount:     50,
			expectedStart: 0,
			expectedLen:   50,
			expectedFirst: "line-0",
			expectedLast:  "line-49",
			truncated:     false,
		},
		{
			name:           "cursorInMiddleReturnsOlderChunk",
			cursor:         "150",
			lineCount:      500,
			expectedStart:  150,
			expectedLen:    maxLogPreviewLines,
			expectedFirst:  "line-150",
			expectedLast:   fmt.Sprintf("line-%d", 150+maxLogPreviewLines-1),
			expectedCursor: "0",
			truncated:      true,
		},
		{
			name:          "cursorAtBeginningHasNoFurtherPages",
			cursor:        "0",
			lineCount:     500,
			expectedStart: 0,
			expectedLen:   maxLogPreviewLines,
			expectedFirst: "line-0",
			expectedLast:  fmt.Sprintf("line-%d", maxLogPreviewLines-1),
			truncated:     true,
		},
		{
			name:           "cursorBeyondEndReturnsEmptyPreview",
			cursor:         "9999",
			lineCount:      50,
			expectedStart:  9999,
			expectedLen:    0,
			expectedCursor: "9799",
			truncated:      true,
		},
	}

	for _, tc := range testCases {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			events := makeLogEvents(tc.lineCount)
			env := newSelfHostedTestEnv(t, func(w http.ResponseWriter, r *http.Request) {
				resp := logResponse{Events: events}
				w.Header().Set("Content-Type", "application/json")
				json.NewEncoder(w).Encode(resp)
			})

			args := map[string]any{"job_id": selfHostedTestJobID}
			if tc.cursor != "" {
				args["cursor"] = tc.cursor
			}
			_, result := callLogsHandler(t, env.Handler, args)

			if result.StartLine != tc.expectedStart {
				toFail(t, "expected start line %d, got %d", tc.expectedStart, result.StartLine)
			}
			if len(result.Preview) != tc.expectedLen {
				toFail(t, "expected preview length %d, got %d", tc.expectedLen, len(result.Preview))
			}
			if tc.expectedLen > 0 {
				if got := result.Preview[0]; got != tc.expectedFirst {
					toFail(t, "unexpected first preview line: %s", got)
				}
				if got := result.Preview[len(result.Preview)-1]; got != tc.expectedLast {
					toFail(t, "unexpected last preview line: %s", got)
				}
			}
			if result.NextCursor != tc.expectedCursor {
				toFail(t, "expected next cursor %q, got %q", tc.expectedCursor, result.NextCursor)
			}
			if result.PreviewTruncated != tc.truncated {
				toFail(t, "expected truncated=%v, got %v", tc.truncated, result.PreviewTruncated)
			}
		})
	}
}

func TestDownloadSelfHostedLogs(t *testing.T) {
	ctx := context.Background()

	t.Run("validResponse", func(t *testing.T) {
		ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			resp := logResponse{
				Events: []logEvent{
					{Output: "first line\nsecond line\n"},
					{Output: "third line\n"},
				},
			}
			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode(resp)
		}))
		defer ts.Close()

		lines, err := downloadSelfHostedLogs(ctx, ts.URL)
		if err != nil {
			toFail(t, "unexpected error: %v", err)
		}
		if len(lines) != 3 {
			toFail(t, "expected 3 lines, got %d: %v", len(lines), lines)
		}
		if lines[0] != "first line" || lines[1] != "second line" || lines[2] != "third line" {
			toFail(t, "unexpected lines: %v", lines)
		}
	})

	t.Run("emptyEvents", func(t *testing.T) {
		ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			resp := logResponse{Events: []logEvent{}}
			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode(resp)
		}))
		defer ts.Close()

		lines, err := downloadSelfHostedLogs(ctx, ts.URL)
		if err != nil {
			toFail(t, "unexpected error: %v", err)
		}
		if lines != nil {
			toFail(t, "expected nil lines for empty events, got %v", lines)
		}
	})

	t.Run("serverError", func(t *testing.T) {
		ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			w.WriteHeader(http.StatusInternalServerError)
		}))
		defer ts.Close()

		lines, err := downloadSelfHostedLogs(ctx, ts.URL)
		if err == nil {
			toFail(t, "expected error for 500 status, got lines: %v", lines)
		}
		if !strings.Contains(err.Error(), "HTTP 500") {
			toFail(t, "expected HTTP 500 error message, got: %v", err)
		}
	})

	t.Run("invalidJSON", func(t *testing.T) {
		ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			w.Write([]byte("not json"))
		}))
		defer ts.Close()

		lines, err := downloadSelfHostedLogs(ctx, ts.URL)
		if err == nil {
			toFail(t, "expected error for invalid JSON, got lines: %v", lines)
		}
		if !strings.Contains(err.Error(), "parse log response JSON") {
			toFail(t, "expected JSON parse error, got: %v", err)
		}
	})

	t.Run("responseTooLarge", func(t *testing.T) {
		ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			w.Header().Set("Content-Type", "application/json")
			// Write a response that exceeds maxLogDownloadBytes.
			// Start with valid JSON prefix, then pad to exceed the limit.
			w.Write([]byte(`{"events":[{"output":"`))
			padding := make([]byte, maxLogDownloadBytes)
			for i := range padding {
				padding[i] = 'x'
			}
			w.Write(padding)
			w.Write([]byte(`"}]}`))
		}))
		defer ts.Close()

		lines, err := downloadSelfHostedLogs(ctx, ts.URL)
		if err == nil {
			toFail(t, "expected error for oversized response, got lines: %v", lines)
		}
		if err != errLogResponseTooLarge {
			toFail(t, "expected errLogResponseTooLarge, got: %v", err)
		}
	})
}

func TestSelfHostedLogsCacheAvoidsDuplicateDownload(t *testing.T) {
	downloadCount := 0
	env := newSelfHostedTestEnv(t, func(w http.ResponseWriter, r *http.Request) {
		downloadCount++
		resp := logResponse{
			Events: []logEvent{{Output: "cached-line-1\ncached-line-2\n"}},
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(resp)
	})

	// First call: should download from server and cache.
	_, result1 := callLogsHandler(t, env.Handler, map[string]any{"job_id": selfHostedTestJobID})
	if len(result1.Preview) != 2 {
		toFail(t, "expected 2 preview lines on first call, got %d", len(result1.Preview))
	}
	if downloadCount != 1 {
		toFail(t, "expected 1 download on first call, got %d", downloadCount)
	}

	// Second call: should use cached lines without hitting the server.
	_, result2 := callLogsHandler(t, env.Handler, map[string]any{"job_id": selfHostedTestJobID})
	if len(result2.Preview) != 2 {
		toFail(t, "expected 2 preview lines on second call, got %d", len(result2.Preview))
	}
	if downloadCount != 1 {
		toFail(t, "expected still 1 download after cache hit, got %d", downloadCount)
	}

	// Verify cached response includes token metadata (Issue 5).
	if result2.Token == "" {
		toFail(t, "expected Token in cached response")
	}
	expectedURL := fmt.Sprintf("https://acme.semaphoreci.com/api/v1/logs/%s?jwt=token", selfHostedTestJobID)
	if result2.LogsURL != expectedURL {
		toFail(t, "expected LogsURL %q in cached response, got %q", expectedURL, result2.LogsURL)
	}
}

func TestLogsPermissionDenied(t *testing.T) {
	jobID := "99999999-aaaa-bbbb-cccc-dddddddddddd"
	orgID := "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
	jobClient := &jobClientStub{
		describeResp: &jobpb.DescribeResponse{
			Status: &responsepb.ResponseStatus{Code: responsepb.ResponseStatus_OK},
			Job: &jobpb.Job{
				Id:             jobID,
				ProjectId:      testProjectUUID,
				OrganizationId: orgID,
				SelfHosted:     false,
			},
		},
	}
	loghubClient := &loghubClientStub{}
	rbac := newRBACStub()

	provider := &support.MockProvider{
		JobClient:    jobClient,
		LoghubClient: loghubClient,
		RBACClient:   rbac,
		Timeout:      time.Second,
	}

	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"job_id": jobID,
	}}}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", "99999999-aaaa-bbbb-cccc-dddddddddddd")
	req.Header = header

	res, err := logsHandler(provider, downloadSelfHostedLogs)(context.Background(), req)
	if err != nil {
		toFail(t, "handler error: %v", err)
	}

	msg := requireErrorText(t, res)
	if !strings.Contains(msg, `Permission denied while accessing project `+testProjectUUID) {
		toFail(t, "expected project denial message, got %q", msg)
	}
	if len(rbac.lastRequests) != 1 {
		toFail(t, "expected one RBAC request, got %d", len(rbac.lastRequests))
	}
	if loghubClient.lastRequest != nil {
		toFail(t, "expected no loghub call, got %+v", loghubClient.lastRequest)
	}
}

func TestLogsMissingOrgFromJob(t *testing.T) {
	jobID := "99999999-aaaa-bbbb-cccc-dddddddddddd"
	jobClient := &jobClientStub{
		describeResp: &jobpb.DescribeResponse{
			Status: &responsepb.ResponseStatus{Code: responsepb.ResponseStatus_OK},
			Job: &jobpb.Job{
				Id:             jobID,
				ProjectId:      testProjectUUID,
				OrganizationId: "",
				SelfHosted:     false,
			},
		},
	}
	loghubClient := &loghubClientStub{}
	rbac := newRBACStub("project.view")

	provider := &support.MockProvider{
		JobClient:    jobClient,
		LoghubClient: loghubClient,
		RBACClient:   rbac,
		Timeout:      time.Second,
	}

	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"job_id": jobID,
	}}}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", "99999999-aaaa-bbbb-cccc-dddddddddddd")
	req.Header = header

	res, err := logsHandler(provider, downloadSelfHostedLogs)(context.Background(), req)
	if err != nil {
		toFail(t, "handler error: %v", err)
	}

	msg := requireErrorText(t, res)
	if !strings.Contains(msg, "job organization_id") {
		toFail(t, "expected organization validation error, got %q", msg)
	}
	if len(rbac.lastRequests) != 0 {
		toFail(t, "expected no RBAC calls, got %d", len(rbac.lastRequests))
	}
	if loghubClient.lastRequest != nil {
		toFail(t, "expected no loghub call, got %+v", loghubClient.lastRequest)
	}
}

func TestLogsRBACUnavailable(t *testing.T) {
	jobID := "99999999-aaaa-bbbb-cccc-dddddddddddd"
	orgID := "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
	jobClient := &jobClientStub{
		describeResp: &jobpb.DescribeResponse{
			Status: &responsepb.ResponseStatus{Code: responsepb.ResponseStatus_OK},
			Job: &jobpb.Job{
				Id:             jobID,
				ProjectId:      testProjectUUID,
				OrganizationId: orgID,
				SelfHosted:     false,
			},
		},
	}
	loghubClient := &loghubClientStub{}

	provider := &support.MockProvider{
		JobClient:    jobClient,
		LoghubClient: loghubClient,
		Timeout:      time.Second,
	}

	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"job_id": jobID,
	}}}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", "99999999-aaaa-bbbb-cccc-dddddddddddd")
	req.Header = header

	res, err := logsHandler(provider, downloadSelfHostedLogs)(context.Background(), req)
	if err != nil {
		toFail(t, "handler error: %v", err)
	}

	msg := requireErrorText(t, res)
	if !strings.Contains(msg, "Authorization service is not configured") {
		toFail(t, "expected RBAC unavailable message, got %q", msg)
	}
	if loghubClient.lastRequest != nil {
		toFail(t, "expected no loghub call, got %+v", loghubClient.lastRequest)
	}
}

func TestBuildLogsURL(t *testing.T) {
	jobID := "job-123"
	url := buildLogsURL("semaphoreci.com", "acme", jobID, "token")
	expected := fmt.Sprintf("https://acme.semaphoreci.com/api/v1/logs/%s?jwt=token", jobID)
	if url != expected {
		toFail(t, "expected %q, got %q", expected, url)
	}
}

func TestBuildLogsURLMissingValues(t *testing.T) {
	if url := buildLogsURL("semaphoreci.com", "", "job-123", "token"); url != "" {
		toFail(t, "expected empty URL when org username missing, got %q", url)
	}
	if url := buildLogsURL("semaphoreci.com", "acme", "job-123", ""); url != "" {
		toFail(t, "expected empty URL when token missing, got %q", url)
	}
}

type jobClientStub struct {
	jobpb.JobServiceClient
	describeResp *jobpb.DescribeResponse
	describeErr  error
	lastDescribe *jobpb.DescribeRequest
}

func (s *jobClientStub) Describe(ctx context.Context, in *jobpb.DescribeRequest, opts ...grpc.CallOption) (*jobpb.DescribeResponse, error) {
	s.lastDescribe = in
	if s.describeErr != nil {
		return nil, s.describeErr
	}
	return s.describeResp, nil
}

func (s *jobClientStub) List(context.Context, *jobpb.ListRequest, ...grpc.CallOption) (*jobpb.ListResponse, error) {
	panic("not implemented")
}

func (s *jobClientStub) ListDebugSessions(context.Context, *jobpb.ListDebugSessionsRequest, ...grpc.CallOption) (*jobpb.ListDebugSessionsResponse, error) {
	panic("not implemented")
}

func (s *jobClientStub) Count(context.Context, *jobpb.CountRequest, ...grpc.CallOption) (*jobpb.CountResponse, error) {
	panic("not implemented")
}

func (s *jobClientStub) CountByState(context.Context, *jobpb.CountByStateRequest, ...grpc.CallOption) (*jobpb.CountByStateResponse, error) {
	panic("not implemented")
}

func (s *jobClientStub) Stop(context.Context, *jobpb.StopRequest, ...grpc.CallOption) (*jobpb.StopResponse, error) {
	panic("not implemented")
}

func (s *jobClientStub) TotalExecutionTime(context.Context, *jobpb.TotalExecutionTimeRequest, ...grpc.CallOption) (*jobpb.TotalExecutionTimeResponse, error) {
	panic("not implemented")
}

func (s *jobClientStub) GetAgentPayload(context.Context, *jobpb.GetAgentPayloadRequest, ...grpc.CallOption) (*jobpb.GetAgentPayloadResponse, error) {
	panic("not implemented")
}

func (s *jobClientStub) CanDebug(context.Context, *jobpb.CanDebugRequest, ...grpc.CallOption) (*jobpb.CanDebugResponse, error) {
	panic("not implemented")
}

func (s *jobClientStub) CanAttach(context.Context, *jobpb.CanAttachRequest, ...grpc.CallOption) (*jobpb.CanAttachResponse, error) {
	panic("not implemented")
}

func (s *jobClientStub) Create(context.Context, *jobpb.CreateRequest, ...grpc.CallOption) (*jobpb.CreateResponse, error) {
	panic("not implemented")
}

type loghubClientStub struct {
	loghubpb.LoghubClient
	resp        *loghubpb.GetLogEventsResponse
	err         error
	lastRequest *loghubpb.GetLogEventsRequest
}

func (s *loghubClientStub) GetLogEvents(ctx context.Context, in *loghubpb.GetLogEventsRequest, opts ...grpc.CallOption) (*loghubpb.GetLogEventsResponse, error) {
	s.lastRequest = in
	if s.err != nil {
		return nil, s.err
	}
	return s.resp, nil
}

type loghub2ClientStub struct {
	loghub2pb.Loghub2Client
	resp        *loghub2pb.GenerateTokenResponse
	err         error
	lastRequest *loghub2pb.GenerateTokenRequest
}

func (s *loghub2ClientStub) GenerateToken(ctx context.Context, in *loghub2pb.GenerateTokenRequest, opts ...grpc.CallOption) (*loghub2pb.GenerateTokenResponse, error) {
	s.lastRequest = in
	if s.err != nil {
		return nil, s.err
	}
	return s.resp, nil
}

type orgClientStub struct {
	orgpb.OrganizationServiceClient
	resp        *orgpb.DescribeResponse
	err         error
	lastRequest *orgpb.DescribeRequest
}

func (s *orgClientStub) Describe(ctx context.Context, in *orgpb.DescribeRequest, opts ...grpc.CallOption) (*orgpb.DescribeResponse, error) {
	s.lastRequest = in
	if s.err != nil {
		return nil, s.err
	}
	return s.resp, nil
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

func toFail(t *testing.T, format string, args ...any) {
	t.Helper()
	t.Fatalf(format, args...)
}
