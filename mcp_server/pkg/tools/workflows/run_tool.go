package workflows

import (
	"context"
	"fmt"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"unicode/utf8"

	"github.com/google/uuid"
	"github.com/mark3labs/mcp-go/mcp"
	"github.com/mark3labs/mcp-go/server"
	"github.com/sirupsen/logrus"

	"github.com/semaphoreio/semaphore/mcp_server/pkg/authz"
	workflowpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/plumber_w_f.workflow"
	projecthubpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/projecthub"
	repopb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/repository_integrator"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/internalapi"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/logging"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/tools/internal/shared"
)

func runFullDescription() string {
	return `Schedule a new workflow run for a project.

Use this when you need to:
- Kick off a pipeline with a specific branch, tag, or commit
- Trigger a workflow with custom parameters without using the UI

Required inputs:
- organization_id: Organization UUID that owns the project
- project_id: Project UUID where the workflow should run
- reference: Git reference (branch, tag, or pull request), e.g. "refs/heads/main", "refs/tags/v1.0", or "refs/pull/42"

Optional inputs:
- commit_sha: Pin the run to a specific commit
- pipeline_file: Override the pipeline definition path (defaults to the project's configured file)
- parameters: A key/value map of parameters to expose as environment variables (values convert to strings)

The authenticated user must have permissions to run workflows in the specified project.`
}

func newRunTool(name, description string) mcp.Tool {
	return mcp.NewTool(
		name,
		mcp.WithDescription(description),
		mcp.WithString(
			"project_id",
			mcp.Required(),
			mcp.Description("Project UUID where the workflow should run."),
			mcp.Pattern(`^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`),
		),
		mcp.WithString(
			"organization_id",
			mcp.Required(),
			mcp.Description("Organization UUID that owns the project."),
			mcp.Pattern(`^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`),
		),
		mcp.WithString(
			"reference",
			mcp.Required(),
			mcp.Description("Git reference to run (branch, tag, or pull request, refs/... pattern)."),
		),
		mcp.WithString(
			"commit_sha",
			mcp.Description("Optional commit SHA to pin the workflow run."),
		),
		mcp.WithString(
			"pipeline_file",
			mcp.Description("Optional pipeline definition YAML file path within the repository."),
		),
		mcp.WithObject(
			"parameters",
			mcp.Description("Optional key/value parameters exposed as environment variables."),
			mcp.AdditionalProperties(map[string]any{
				"oneOf": []any{
					map[string]any{"type": "string"},
					map[string]any{"type": "number"},
					map[string]any{"type": "boolean"},
					map[string]any{"type": "null"},
				},
			}),
		),
		mcp.WithIdempotentHintAnnotation(false),
	)
}

func runHandler(api internalapi.Provider) server.ToolHandlerFunc {
	return func(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
		orgIDRaw, err := req.RequireString("organization_id")
		if err != nil {
			return mcp.NewToolResultError(`Missing required argument: organization_id. Provide the organization UUID returned by organizations_list.`), nil
		}
		orgID := strings.TrimSpace(orgIDRaw)
		if err := shared.ValidateUUID(orgID, "organization_id"); err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		if err := shared.EnsureWriteToolsFeature(ctx, api, orgID); err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		tracker := shared.TrackToolExecution(ctx, runToolName, orgID)
		defer tracker.Cleanup()

		workflowClient := api.Workflow()
		if workflowClient == nil {
			return mcp.NewToolResultError(missingWorkflowError), nil
		}
		projectClient := api.Projects()
		if projectClient == nil {
			return mcp.NewToolResultError("project gRPC endpoint is not configured"), nil
		}

		projectIDRaw, err := req.RequireString("project_id")
		if err != nil {
			return mcp.NewToolResultError(`Missing required argument: project_id. Provide the project UUID (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx).`), nil
		}
		projectID := strings.TrimSpace(projectIDRaw)
		if err := shared.ValidateUUID(projectID, "project_id"); err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		userID := strings.ToLower(strings.TrimSpace(req.Header.Get("X-Semaphore-User-ID")))
		if err := shared.ValidateUUID(userID, "x-semaphore-user-id header"); err != nil {
			return mcp.NewToolResultError(fmt.Sprintf(`%v

The authentication layer must inject the X-Semaphore-User-ID header so we can authorize workflow runs.`, err)), nil
		}

		if err := authz.CheckProjectPermission(ctx, api, userID, orgID, projectID, projectRunPermission); err != nil {
			return shared.ProjectAuthorizationError(err, orgID, projectID, projectRunPermission), nil
		}

		referenceRaw, err := req.RequireString("reference")
		if err != nil {
			return mcp.NewToolResultError(`Missing required argument: reference. Provide the branch or git ref to run.`), nil
		}
		reference, err := sanitizeGitReference(referenceRaw, "reference")
		if err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		commitSHA := strings.TrimSpace(req.GetString("commit_sha", ""))
		if err := validateCommitSHA(commitSHA, "commit_sha"); err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		pipelineFileInput := strings.TrimSpace(req.GetString("pipeline_file", ""))
		if err := validatePipelineFile(pipelineFileInput, "pipeline_file"); err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		parameters, err := extractParameters(req.GetArguments()["parameters"])
		if err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		describeReq := projectDescribeRequest(projectID, orgID, userID)
		callCtx, cancel := context.WithTimeout(ctx, api.CallTimeout())
		defer cancel()

		describeResp, err := projectClient.Describe(callCtx, describeReq)
		if err != nil {
			logging.ForComponent("rpc").
				WithFields(logrus.Fields{
					"rpc":       "project.Describe",
					"projectId": projectID,
					"orgId":     orgID,
				}).
				WithError(err).
				Error("project describe RPC failed")
			return mcp.NewToolResultError("Unable to load project details. Please confirm the project exists and retry."), nil
		}

		project, err := validateProjectDescribeResponse(describeResp, orgID, projectID)
		if err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		spec := project.GetSpec()
		if spec == nil {
			return mcp.NewToolResultError("Project specification is missing. Please try again once the project is fully initialized."), nil
		}

		repo := spec.GetRepository()
		if repo == nil {
			return mcp.NewToolResultError("Project repository configuration is missing. Configure the repository before scheduling workflows."), nil
		}

		pipelineFile := pipelineFileInput
		if pipelineFile == "" {
			pipelineFile = strings.TrimSpace(repo.GetPipelineFile())
			if pipelineFile == "" {
				pipelineFile = defaultPipelineFile
			}
		}
		if err := validatePipelineFile(pipelineFile, "pipeline_file"); err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		envVars, err := buildEnvVars(parameters)
		if err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		requestToken := uuid.NewString()
		branchName := branchNameFromReference(reference)
		label := labelFromReference(reference)
		gitReference := ensureGitReference(reference)

		serviceType, err := mapIntegrationType(repo.GetIntegrationType())
		if err != nil {
			logging.ForComponent("workflows").
				WithFields(logrus.Fields{
					"projectId":       projectID,
					"orgId":           orgID,
					"integrationType": repo.GetIntegrationType(),
				}).
				WithError(err).
				Error("unsupported repository integration type")
			return mcp.NewToolResultError("Project repository integration type is not supported. Please contact support."), nil
		}

		scheduleReq := &workflowpb.ScheduleRequest{
			ProjectId:             projectID,
			OrganizationId:        orgID,
			RequesterId:           userID,
			DefinitionFile:        pipelineFile,
			RequestToken:          requestToken,
			GitReference:          gitReference,
			Label:                 label,
			TriggeredBy:           workflowpb.TriggeredBy_API,
			StartInConceivedState: true,
			Service:               serviceType,
			EnvVars:               envVars,
			Repo: &workflowpb.ScheduleRequest_Repo{
				Owner:        strings.TrimSpace(repo.GetOwner()),
				RepoName:     strings.TrimSpace(repo.GetName()),
				BranchName:   branchName,
				CommitSha:    commitSHA,
				RepositoryId: strings.TrimSpace(repo.GetId()),
			},
		}
		scheduleCtx, cancelSchedule := context.WithTimeout(ctx, api.CallTimeout())
		defer cancelSchedule()

		scheduleResp, err := workflowClient.Schedule(scheduleCtx, scheduleReq)
		if err != nil {
			logging.ForComponent("rpc").
				WithFields(logrus.Fields{
					"rpc":       "workflow.Schedule",
					"projectId": projectID,
					"orgId":     orgID,
					"reference": reference,
				}).
				WithError(err).
				Error("workflow schedule RPC failed")
			return mcp.NewToolResultError("Workflow schedule failed. Verify the repository settings and try again."), nil
		}

		if err := shared.CheckStatus(scheduleResp.GetStatus()); err != nil {
			return mcp.NewToolResultError(fmt.Sprintf("Workflow schedule failed: %v", err)), nil
		}

		result := runResult{
			WorkflowID:   strings.TrimSpace(scheduleResp.GetWfId()),
			PipelineID:   strings.TrimSpace(scheduleResp.GetPplId()),
			Reference:    gitReference,
			CommitSHA:    commitSHA,
			PipelineFile: pipelineFile,
		}

		markdown := formatRunMarkdown(result)
		markdown = shared.TruncateResponse(markdown, shared.MaxResponseChars)

		tracker.MarkSuccess()
		return &mcp.CallToolResult{
			Content:           []mcp.Content{mcp.NewTextContent(markdown)},
			StructuredContent: result,
		}, nil
	}
}

var (
	commitPattern    = regexp.MustCompile(`^[0-9a-f]{7,64}$`)
	parameterPattern = regexp.MustCompile(`^[A-Za-z_][A-Za-z0-9_]*$`)
)

func sanitizeGitReference(raw, field string) (string, error) {
	value := strings.TrimSpace(raw)
	if value == "" {
		return "", fmt.Errorf("%s is required", field)
	}
	return shared.SanitizeBranch(value, field)
}

func validateCommitSHA(value, field string) error {
	value = strings.TrimSpace(value)
	if value == "" {
		return nil
	}
	if len(value) > 64 {
		return fmt.Errorf("%s must not exceed 64 characters", field)
	}
	if !commitPattern.MatchString(strings.ToLower(value)) {
		return fmt.Errorf("%s must be a hexadecimal SHA (7-64 characters)", field)
	}
	return nil
}

func validatePipelineFile(value, field string) error {
	value = strings.TrimSpace(value)
	if value == "" {
		return nil
	}
	length := utf8.RuneCountInString(value)
	if length > 512 {
		return fmt.Errorf("%s must not exceed 512 characters", field)
	}
	for _, r := range value {
		if r < 32 || r == 127 {
			return fmt.Errorf("%s contains control characters", field)
		}
		if r == '\\' {
			return fmt.Errorf("%s must not contain backslashes", field)
		}
	}
	if strings.Contains(value, "..") {
		return fmt.Errorf("%s must not contain '..' sequences", field)
	}
	if strings.HasPrefix(value, "/") {
		return fmt.Errorf("%s must be a relative path", field)
	}
	return nil
}

func extractParameters(raw any) (map[string]any, error) {
	if raw == nil {
		return nil, nil
	}
	params, ok := raw.(map[string]any)
	if !ok {
		return nil, fmt.Errorf("parameters must be a key/value map with string keys")
	}
	return params, nil
}

func buildEnvVars(params map[string]any) ([]*workflowpb.ScheduleRequest_EnvVar, error) {
	if len(params) == 0 {
		return nil, nil
	}
	names := make([]string, 0, len(params))
	for name := range params {
		names = append(names, name)
	}
	sort.Strings(names)
	result := make([]*workflowpb.ScheduleRequest_EnvVar, 0, len(names))
	for _, name := range names {
		clean := strings.TrimSpace(name)
		if clean == "" {
			return nil, fmt.Errorf("parameter names must not be empty")
		}
		if err := validateParameterName(clean); err != nil {
			return nil, err
		}
		value, err := parameterValueToString(params[name])
		if err != nil {
			return nil, err
		}
		result = append(result, &workflowpb.ScheduleRequest_EnvVar{Name: clean, Value: value})
	}
	return result, nil
}

func validateParameterName(name string) error {
	if utf8.RuneCountInString(name) > 128 {
		return fmt.Errorf("parameter names must not exceed 128 characters")
	}
	for _, r := range name {
		if r < 32 || r == 127 {
			return fmt.Errorf("parameter %q contains control characters", name)
		}
	}
	if !parameterPattern.MatchString(name) {
		return fmt.Errorf("parameter %q must start with a letter or underscore, followed by letters, digits, or underscores", name)
	}
	return nil
}

func parameterValueToString(value any) (string, error) {
	switch v := value.(type) {
	case nil:
		return "", nil
	case string:
		return v, nil
	case bool:
		if v {
			return "true", nil
		}
		return "false", nil
	case float64:
		return strconv.FormatFloat(v, 'f', -1, 64), nil
	case int:
		return strconv.Itoa(v), nil
	case int32:
		return strconv.FormatInt(int64(v), 10), nil
	case int64:
		return strconv.FormatInt(v, 10), nil
	case uint32:
		return strconv.FormatUint(uint64(v), 10), nil
	case uint64:
		return strconv.FormatUint(v, 10), nil
	default:
		return "", fmt.Errorf("parameters values must be strings, numbers, booleans, or null")
	}
}

func projectDescribeRequest(projectID, orgID, userID string) *projecthubpb.DescribeRequest {
	return &projecthubpb.DescribeRequest{
		Id: projectID,
		Metadata: &projecthubpb.RequestMeta{
			ApiVersion: "v1alpha",
			Kind:       "Project",
			OrgId:      strings.TrimSpace(orgID),
			UserId:     strings.TrimSpace(userID),
			ReqId:      uuid.NewString(),
		},
	}
}

func validateProjectDescribeResponse(resp *projecthubpb.DescribeResponse, orgID, projectID string) (*projecthubpb.Project, error) {
	if resp == nil {
		return nil, fmt.Errorf("Project describe returned no data")
	}
	meta := resp.GetMetadata()
	if meta == nil || meta.GetStatus() == nil {
		return nil, fmt.Errorf("Project describe response is missing status information")
	}
	if meta.GetStatus().GetCode() != projecthubpb.ResponseMeta_OK {
		message := strings.TrimSpace(meta.GetStatus().GetMessage())
		if message == "" {
			message = "Project describe request failed"
		}
		return nil, fmt.Errorf("%s", message)
	}
	project := resp.GetProject()
	if project == nil {
		return nil, fmt.Errorf("Project describe response did not include project details")
	}
	projMeta := project.GetMetadata()
	if projMeta == nil {
		return nil, fmt.Errorf("Project metadata is missing")
	}
	if resourceOrg := strings.TrimSpace(projMeta.GetOrgId()); resourceOrg == "" || !strings.EqualFold(resourceOrg, orgID) {
		shared.ReportScopeMismatch(shared.ScopeMismatchMetadata{
			Tool:              runToolName,
			ResourceType:      "project",
			ResourceID:        projMeta.GetId(),
			RequestOrgID:      orgID,
			ResourceOrgID:     resourceOrg,
			RequestProjectID:  projectID,
			ResourceProjectID: projMeta.GetId(),
		})
		return nil, fmt.Errorf("Project %s does not belong to organization %s", projectID, orgID)
	}
	return project, nil
}

// branchNameFromReference extracts the branch name from a git reference.
// Note: Tags intentionally return the full "refs/tags/*" path as required by the workflow service API.
func branchNameFromReference(ref string) string {
	value := strings.TrimSpace(ref)
	switch {
	case strings.HasPrefix(value, "refs/heads/"):
		return strings.TrimPrefix(value, "refs/heads/")
	case strings.HasPrefix(value, "refs/tags/"):
		return value // Workflow service expects full path for tags
	case strings.HasPrefix(value, "refs/pull/"):
		return "pull-request-" + strings.TrimPrefix(value, "refs/pull/")
	default:
		return value
	}
}

func labelFromReference(ref string) string {
	value := strings.TrimSpace(ref)
	switch {
	case strings.HasPrefix(value, "refs/tags/"):
		return strings.TrimPrefix(value, "refs/tags/")
	case strings.HasPrefix(value, "refs/pull/"):
		return strings.TrimPrefix(value, "refs/pull/")
	case strings.HasPrefix(value, "refs/heads/"):
		return strings.TrimPrefix(value, "refs/heads/")
	default:
		return value
	}
}

func ensureGitReference(ref string) string {
	ref = strings.TrimSpace(ref)
	if strings.HasPrefix(ref, "refs/") {
		return ref
	}
	return "refs/heads/" + ref
}

func mapIntegrationType(integration repopb.IntegrationType) (workflowpb.ScheduleRequest_ServiceType, error) {
	switch integration {
	case repopb.IntegrationType_GITHUB_OAUTH_TOKEN:
		return workflowpb.ScheduleRequest_GIT_HUB, nil
	case repopb.IntegrationType_GITHUB_APP:
		return workflowpb.ScheduleRequest_GIT_HUB, nil
	case repopb.IntegrationType_BITBUCKET:
		return workflowpb.ScheduleRequest_BITBUCKET, nil
	case repopb.IntegrationType_GITLAB:
		return workflowpb.ScheduleRequest_GITLAB, nil
	case repopb.IntegrationType_GIT:
		return workflowpb.ScheduleRequest_GIT, nil
	default:
		return workflowpb.ScheduleRequest_GIT_HUB, fmt.Errorf("unsupported repository integration type: %v", integration)
	}
}

func formatRunMarkdown(result runResult) string {
	mb := shared.NewMarkdownBuilder()
	mb.H1("Workflow Scheduled")
	if result.WorkflowID != "" {
		mb.KeyValue("Workflow ID", fmt.Sprintf("`%s`", result.WorkflowID))
	}
	if result.PipelineID != "" {
		mb.KeyValue("Initial Pipeline", fmt.Sprintf("`%s`", result.PipelineID))
	}
	if result.Reference != "" {
		mb.KeyValue("Reference", result.Reference)
	}
	if result.CommitSHA != "" {
		mb.KeyValue("Commit", shortenCommit(result.CommitSHA))
	}
	if result.PipelineFile != "" {
		mb.KeyValue("Pipeline File", result.PipelineFile)
	}
	return mb.String()
}
