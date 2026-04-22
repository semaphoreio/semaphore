package jobs

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"strings"

	"github.com/mark3labs/mcp-go/mcp"
	"github.com/mark3labs/mcp-go/server"
	"github.com/sirupsen/logrus"

	"github.com/semaphoreio/semaphore/mcp_server/pkg/authz"
	artifacthubpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/artifacthub"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/internalapi"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/logging"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/tools/internal/clients"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/tools/internal/shared"
)

const (
	artifactJobLogsToolName = "artifact_job_logs"
	artifactJobLogsSource   = "artifacthub"
)

var (
	uploadedArtifactJobLogCandidates = []string{
		"agent/job_logs.txt",
		"agent/job_logs.txt.gz",
	}
	errUploadedArtifactJobLogsNotFound = errors.New("uploaded artifact job logs not found")
)

type artifactJobLogsResult struct {
	JobID          string `json:"jobId"`
	OrganizationID string `json:"organizationId"`
	ProjectID      string `json:"projectId"`
	Source         string `json:"source"`
	Path           string `json:"path"`
	Method         string `json:"method"`
	URL            string `json:"url"`
}

func artifactJobLogsFullDescription() string {
	return `Fetch a signed URL for artifact job logs uploaded by agents.

Use this when you explicitly need artifact-uploaded job logs (for example when live logs were trimmed).

Requirements:
- The organization must have at least one feature enabled: mcp_server_artifacts_tools or artifacts_job_logs.
- The caller must have both project.view and project.artifacts.view permissions.

Behavior:
- Searches the job artifact directory "agent/" and picks the first available file in priority order:
  1) agent/job_logs.txt
  2) agent/job_logs.txt.gz
- Returns a signed GET URL for the selected file.

Example:
1. Get artifact job logs signed URL:
   artifact_job_logs(organization_id="...", job_id="...")
`
}

func newArtifactJobLogsTool(name, description string) mcp.Tool {
	return mcp.NewTool(
		name,
		mcp.WithDescription(description),
		mcp.WithString(
			"organization_id",
			mcp.Required(),
			mcp.Description("Organization UUID context for this job (format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx). Use the ID returned by semaphore_organizations_list."),
			mcp.Pattern(`^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`),
		),
		mcp.WithString(
			"job_id",
			mcp.Required(),
			mcp.Description("Job UUID to fetch artifact job logs for (format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)."),
			mcp.Pattern(`^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`),
		),
		mcp.WithReadOnlyHintAnnotation(true),
		mcp.WithIdempotentHintAnnotation(true),
		mcp.WithOpenWorldHintAnnotation(true),
	)
}

func artifactJobLogsHandler(api internalapi.Provider) server.ToolHandlerFunc {
	return func(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
		orgIDRaw, err := req.RequireString("organization_id")
		if err != nil {
			return mcp.NewToolResultError("organization_id is required. Use organizations_list to capture the correct organization ID before fetching artifact job logs."), nil
		}
		orgID := strings.TrimSpace(orgIDRaw)
		if err := shared.ValidateUUID(orgID, "organization_id"); err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		tracker := shared.TrackToolExecution(ctx, artifactJobLogsToolName, orgID)
		defer tracker.Cleanup()

		jobIDRaw, err := req.RequireString("job_id")
		if err != nil {
			return mcp.NewToolResultError("job_id is required. Provide the job UUID shown by jobs_describe."), nil
		}

		jobID := strings.TrimSpace(jobIDRaw)
		if err := shared.ValidateUUID(jobID, "job_id"); err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		userID := strings.ToLower(strings.TrimSpace(req.Header.Get("X-Semaphore-User-ID")))
		if err := shared.ValidateUUID(userID, "x-semaphore-user-id header"); err != nil {
			return mcp.NewToolResultError(fmt.Sprintf(`%v

The authentication layer must inject the X-Semaphore-User-ID header so we can enforce project permissions before generating artifact job logs URLs.

Troubleshooting:
- Ensure requests pass through the authenticated proxy
- Verify the header value is a UUID (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)
- Retry once the header is present`, err)), nil
		}

		job, err := fetchJob(ctx, api, jobID)
		if err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		jobOrg := strings.TrimSpace(job.GetOrganizationId())
		jobProjectID := strings.TrimSpace(job.GetProjectId())
		if jobOrg == "" || !strings.EqualFold(jobOrg, orgID) {
			shared.ReportScopeMismatch(shared.ScopeMismatchMetadata{
				Tool:              artifactJobLogsToolName,
				ResourceType:      "job",
				ResourceID:        jobID,
				RequestOrgID:      orgID,
				ResourceOrgID:     job.GetOrganizationId(),
				RequestProjectID:  "",
				ResourceProjectID: jobProjectID,
			})
			return shared.ScopeMismatchError(artifactJobLogsToolName, "organization"), nil
		}
		if jobProjectID == "" {
			shared.ReportScopeMismatch(shared.ScopeMismatchMetadata{
				Tool:              artifactJobLogsToolName,
				ResourceType:      "job",
				ResourceID:        jobID,
				RequestOrgID:      orgID,
				ResourceOrgID:     jobOrg,
				RequestProjectID:  "",
				ResourceProjectID: jobProjectID,
			})
			return shared.ScopeMismatchError(artifactJobLogsToolName, "project"), nil
		}
		if err := shared.ValidateUUID(jobOrg, "job organization_id"); err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}
		if err := shared.ValidateUUID(jobProjectID, "job project_id"); err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		if err := shared.EnsureReadToolsFeature(ctx, api, orgID); err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}
		if err := shared.EnsureArtifactsToolsOrJobLogsFeature(ctx, api, orgID); err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		if err := authz.CheckProjectPermission(ctx, api, userID, orgID, jobProjectID, projectViewPermission); err != nil {
			return shared.ProjectAuthorizationError(err, orgID, jobProjectID, projectViewPermission), nil
		}
		if err := authz.CheckProjectPermission(ctx, api, userID, orgID, jobProjectID, projectArtifactsViewPermission); err != nil {
			return shared.ProjectAuthorizationError(err, orgID, jobProjectID, projectArtifactsViewPermission), nil
		}

		artifactStoreID, toolErr := fetchProjectArtifactStoreIDForArtifactJobLogs(
			ctx,
			api,
			artifactJobLogsToolName,
			orgID,
			userID,
			jobProjectID,
		)
		if toolErr != nil {
			return toolErr, nil
		}
		if artifactStoreID == "" {
			return mcp.NewToolResultError("project is missing an artifact_store_id; cannot retrieve artifact job logs"), nil
		}

		resolvedPath, err := resolveUploadedArtifactJobLogsPath(ctx, api, artifactStoreID, jobID)
		if err != nil {
			if errors.Is(err, errUploadedArtifactJobLogsNotFound) {
				return mcp.NewToolResultError("uploaded artifact job logs not found in agent/ (expected job_logs.txt or job_logs.txt.gz)"), nil
			}
			return mcp.NewToolResultError(err.Error()), nil
		}

		requestPath := uploadedJobArtifactPath(jobID, resolvedPath)
		signedURL, err := getUploadedArtifactJobLogsSignedURL(ctx, api, artifactStoreID, requestPath)
		if err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		result := artifactJobLogsResult{
			JobID:          jobID,
			OrganizationID: jobOrg,
			ProjectID:      jobProjectID,
			Source:         artifactJobLogsSource,
			Path:           resolvedPath,
			Method:         http.MethodGet,
			URL:            signedURL,
		}

		markdown := formatArtifactJobLogsMarkdown(result)
		markdown = shared.TruncateResponse(markdown, shared.MaxResponseChars)

		tracker.MarkSuccess()
		return &mcp.CallToolResult{
			Content:           []mcp.Content{mcp.NewTextContent(markdown)},
			StructuredContent: result,
		}, nil
	}
}

func fetchProjectArtifactStoreIDForArtifactJobLogs(
	ctx context.Context,
	api internalapi.Provider,
	toolName string,
	orgID string,
	userID string,
	projectID string,
) (string, *mcp.CallToolResult) {
	project, err := clients.DescribeProject(ctx, api, orgID, userID, projectID)
	if err != nil {
		return "", mcp.NewToolResultError(err.Error())
	}

	meta := project.GetMetadata()
	if meta == nil {
		return "", mcp.NewToolResultError("describe project returned no metadata")
	}
	projectOrgID := strings.TrimSpace(meta.GetOrgId())
	projectMetaID := strings.TrimSpace(meta.GetId())
	if projectOrgID == "" || !strings.EqualFold(projectOrgID, orgID) {
		shared.ReportScopeMismatch(shared.ScopeMismatchMetadata{
			Tool:              toolName,
			ResourceType:      "project",
			ResourceID:        projectID,
			RequestOrgID:      orgID,
			ResourceOrgID:     projectOrgID,
			RequestProjectID:  projectID,
			ResourceProjectID: projectMetaID,
		})
		return "", shared.ScopeMismatchError(toolName, "organization")
	}
	if projectMetaID != "" && !strings.EqualFold(projectMetaID, projectID) {
		shared.ReportScopeMismatch(shared.ScopeMismatchMetadata{
			Tool:              toolName,
			ResourceType:      "project",
			ResourceID:        projectMetaID,
			RequestOrgID:      orgID,
			ResourceOrgID:     projectOrgID,
			RequestProjectID:  projectID,
			ResourceProjectID: projectMetaID,
		})
		return "", shared.ScopeMismatchError(toolName, "project")
	}

	spec := project.GetSpec()
	if spec == nil {
		return "", nil
	}
	return strings.TrimSpace(spec.GetArtifactStoreId()), nil
}

func resolveUploadedArtifactJobLogsPath(
	ctx context.Context,
	api internalapi.Provider,
	artifactStoreID string,
	jobID string,
) (string, error) {
	client := api.Artifacthub()
	if client == nil {
		return "", fmt.Errorf("artifacthub gRPC endpoint is not configured")
	}

	callCtx, cancel := context.WithTimeout(ctx, api.CallTimeout())
	defer cancel()

	resp, err := client.ListPath(callCtx, &artifacthubpb.ListPathRequest{
		ArtifactId:        artifactStoreID,
		Path:              uploadedJobArtifactPath(jobID, "agent/"),
		UnwrapDirectories: false,
	})
	if err != nil {
		logging.ForComponent("rpc").
			WithFields(logrus.Fields{
				"rpc":        "artifacthub.ListPath",
				"artifactId": artifactStoreID,
				"jobId":      jobID,
				"path":       uploadedJobArtifactPath(jobID, "agent/"),
			}).
			WithError(err).
			Error("gRPC call failed")
		return "", fmt.Errorf("artifacthub ListPath RPC failed: %w", err)
	}

	available := make(map[string]struct{}, len(resp.GetItems()))
	for _, item := range resp.GetItems() {
		if item == nil || item.GetIsDirectory() {
			continue
		}

		relative := relativeJobArtifactPath(item.GetName(), jobID)
		if relative == "" {
			continue
		}
		available[relative] = struct{}{}
	}

	for _, candidate := range uploadedArtifactJobLogCandidates {
		if _, ok := available[candidate]; ok {
			return candidate, nil
		}
	}

	return "", errUploadedArtifactJobLogsNotFound
}

func getUploadedArtifactJobLogsSignedURL(ctx context.Context, api internalapi.Provider, artifactStoreID, path string) (string, error) {
	client := api.Artifacthub()
	if client == nil {
		return "", fmt.Errorf("artifacthub gRPC endpoint is not configured")
	}

	callCtx, cancel := context.WithTimeout(ctx, api.CallTimeout())
	defer cancel()

	resp, err := client.GetSignedURL(callCtx, &artifacthubpb.GetSignedURLRequest{
		ArtifactId: artifactStoreID,
		Path:       path,
		Method:     http.MethodGet,
	})
	if err != nil {
		logging.ForComponent("rpc").
			WithFields(logrus.Fields{
				"rpc":        "artifacthub.GetSignedURL",
				"artifactId": artifactStoreID,
				"path":       path,
				"method":     http.MethodGet,
			}).
			WithError(err).
			Error("gRPC call failed")
		return "", fmt.Errorf("artifacthub GetSignedURL RPC failed: %w", err)
	}

	url := strings.TrimSpace(resp.GetUrl())
	if url == "" {
		return "", fmt.Errorf("artifact service returned malformed response: no signed URL")
	}

	return url, nil
}

func uploadedJobArtifactPath(jobID, relativePath string) string {
	return fmt.Sprintf("artifacts/jobs/%s/%s", strings.TrimSpace(jobID), strings.TrimLeft(relativePath, "/"))
}

func relativeJobArtifactPath(name, jobID string) string {
	trimmed := strings.Trim(strings.TrimSpace(name), "/")
	if trimmed == "" {
		return ""
	}

	prefix := fmt.Sprintf("artifacts/jobs/%s/", strings.TrimSpace(jobID))
	if strings.HasPrefix(trimmed, prefix) {
		trimmed = strings.TrimPrefix(trimmed, prefix)
		trimmed = strings.Trim(trimmed, "/")
	}

	return trimmed
}

func formatArtifactJobLogsMarkdown(result artifactJobLogsResult) string {
	mb := shared.NewMarkdownBuilder()
	mb.H1(fmt.Sprintf("Artifact Job Logs URL for Job %s", result.JobID))
	mb.KeyValue("Organization ID", fmt.Sprintf("`%s`", result.OrganizationID))
	mb.KeyValue("Project ID", fmt.Sprintf("`%s`", result.ProjectID))
	mb.KeyValue("Source", result.Source)
	mb.KeyValue("Resolved Path", fmt.Sprintf("`%s`", result.Path))
	mb.KeyValue("Method", result.Method)
	mb.KeyValue("Signed URL", result.URL)
	mb.Line()
	mb.Paragraph("Use the signed URL to download the artifact job logs directly.")
	return mb.String()
}
