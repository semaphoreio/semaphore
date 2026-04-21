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
   artifact_job_logs(job_id="...")
`
}

func newArtifactJobLogsTool(name, description string) mcp.Tool {
	return mcp.NewTool(
		name,
		mcp.WithDescription(description),
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
		if err := shared.ValidateUUID(jobOrg, "job organization_id"); err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}
		if err := shared.ValidateUUID(jobProjectID, "job project_id"); err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		tracker := shared.TrackToolExecution(ctx, artifactJobLogsToolName, jobOrg)
		defer tracker.Cleanup()

		if err := shared.EnsureReadToolsFeature(ctx, api, jobOrg); err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}
		if err := shared.EnsureArtifactsToolsOrJobLogsFeature(ctx, api, jobOrg); err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		if err := authz.CheckProjectPermission(ctx, api, userID, jobOrg, jobProjectID, projectViewPermission); err != nil {
			return shared.ProjectAuthorizationError(err, jobOrg, jobProjectID, projectViewPermission), nil
		}
		if err := authz.CheckProjectPermission(ctx, api, userID, jobOrg, jobProjectID, projectArtifactsViewPermission); err != nil {
			return shared.ProjectAuthorizationError(err, jobOrg, jobProjectID, projectArtifactsViewPermission), nil
		}

		artifactStoreID, err := fetchProjectArtifactStoreIDForArtifactJobLogs(ctx, api, jobOrg, userID, jobProjectID)
		if err != nil {
			return mcp.NewToolResultError(err.Error()), nil
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
	orgID string,
	userID string,
	projectID string,
) (string, error) {
	project, err := clients.DescribeProject(ctx, api, orgID, userID, projectID)
	if err != nil {
		return "", err
	}

	meta := project.GetMetadata()
	if meta == nil {
		return "", fmt.Errorf("describe project returned no metadata")
	}
	projectOrgID := strings.TrimSpace(meta.GetOrgId())
	if projectOrgID == "" || !strings.EqualFold(projectOrgID, orgID) {
		return "", fmt.Errorf("project belongs to a different organization")
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
