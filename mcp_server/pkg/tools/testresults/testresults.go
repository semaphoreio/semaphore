package testresults

import (
	"context"
	"fmt"
	"path"
	"strings"

	"github.com/mark3labs/mcp-go/mcp"
	"github.com/mark3labs/mcp-go/server"
	"github.com/sirupsen/logrus"

	"github.com/semaphoreio/semaphore/mcp_server/pkg/authz"
	artifacthubpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/artifacthub"
	pipelinepb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/plumber.pipeline"
	projecthubenum "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/projecthub"
	projecthubpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/projecthub"
	jobpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/server_farm.job"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/internalapi"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/logging"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/tools/internal/clients"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/tools/internal/shared"
)

const (
	toolName              = "get_test_results"
	projectViewPermission = "project.view"
)

type resultArtifact struct {
	path        string
	compression string
	contentType string
}

func fullDescription() string {
	return `Fetch aggregated test results for a job or pipeline.

Use this tool to retrieve the pre-parsed JSON summary produced by the MCP pipeline (failed tests
only). Returns a URL to fetch details including failed cases and durations.

Scopes:
- job: Get test results for a specific job
- pipeline: Get aggregated test results across all jobs in a pipeline

Examples:
1. Get job-level test results:
   get_test_results(scope="job", job_id="...")

2. Get pipeline-level test results:
   get_test_results(scope="pipeline", pipeline_id="...")

Typical workflow:
1. Use pipelines_list or pipeline_jobs to identify the job/pipeline ID
2. Call this tool to get the test results URL
3. Download the JSON once (URL expires quickly) and reuse it locally for analysis.`
}

// Register wires the test results URL tool.
func Register(s *server.MCPServer, api internalapi.Provider) {
	handler := handler(api)
	s.AddTool(newTool(), handler)
}

func newTool() mcp.Tool {
	return mcp.NewTool(
		toolName,
		mcp.WithDescription(fullDescription()),
		mcp.WithString(
			"scope",
			mcp.Required(),
			mcp.Description("Scope to fetch test results for: 'job' for individual job results, 'pipeline' for aggregated pipeline results."),
			mcp.Enum("job", "pipeline"),
		),
		mcp.WithString(
			"job_id",
			mcp.Description("Job UUID (required when scope=job). Get this from jobs_describe or pipeline_jobs. Format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx."),
			mcp.Pattern(`^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`),
		),
		mcp.WithString(
			"pipeline_id",
			mcp.Description("Pipeline UUID (required when scope=pipeline). Get this from pipelines_list. Format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx."),
			mcp.Pattern(`^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`),
		),
		mcp.WithReadOnlyHintAnnotation(true),
		mcp.WithIdempotentHintAnnotation(true),
		mcp.WithOpenWorldHintAnnotation(true),
	)
}

func handler(api internalapi.Provider) server.ToolHandlerFunc {
	return func(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
		scope, err := req.RequireString("scope")
		if err != nil {
			return mcp.NewToolResultError("scope is required (job|pipeline)."), nil
		}
		scope = strings.ToLower(strings.TrimSpace(scope))
		if scope != "job" && scope != "pipeline" {
			return mcp.NewToolResultError("scope must be 'job' or 'pipeline'."), nil
		}

		userID := strings.ToLower(strings.TrimSpace(req.Header.Get("X-Semaphore-User-ID")))
		if userID != "" {
			if err := shared.ValidateUUID(userID, "x-semaphore-user-id header"); err != nil {
				return mcp.NewToolResultError(err.Error()), nil
			}
		}

		var tracker *shared.ToolExecutionTracker
		defer func() {
			if tracker != nil {
				tracker.Cleanup()
			}
		}()
		ensureTracker := func(orgID string) {
			if tracker == nil {
				tracker = shared.TrackToolExecution(ctx, toolName, orgID)
			}
		}

		var orgID string
		var projectID string
		var listingDir string
		var artifactCandidates []resultArtifact

		switch scope {
		case "job":
			jobID, err := req.RequireString("job_id")
			if err != nil {
				ensureTracker("")
				return mcp.NewToolResultError(`job_id is required when scope=job.

Provide the job UUID from jobs_describe or pipeline_jobs. Example:
test_results_signed_url(scope="job", job_id="11111111-2222-3333-4444-555555555555")`), nil
			}
			jobID = strings.TrimSpace(jobID)
			if err := shared.ValidateUUID(jobID, "job_id"); err != nil {
				ensureTracker("")
				return mcp.NewToolResultError(err.Error()), nil
			}
			job, err := clients.DescribeJob(ctx, api, jobID)
			if err != nil {
				ensureTracker("")
				return mcp.NewToolResultError(err.Error()), nil
			}
			if job.GetState() != jobpb.Job_FINISHED {
				ensureTracker("")
				return mcp.NewToolResultError(fmt.Sprintf("job is not finished (current state: %s). Test results are only available after the job completes. Use jobs_describe to check job status.", job.GetState().String())), nil
			}
			orgID = strings.TrimSpace(job.GetOrganizationId())
			projectID = strings.TrimSpace(job.GetProjectId())
			if err := shared.ValidateUUID(orgID, "job organization_id"); err != nil {
				ensureTracker("")
				return mcp.NewToolResultError(err.Error()), nil
			}
			if err := shared.ValidateUUID(projectID, "job project_id"); err != nil {
				ensureTracker("")
				return mcp.NewToolResultError(err.Error()), nil
			}
			listingDir = fmt.Sprintf("artifacts/jobs/%s/test-results", jobID)
			artifactCandidates = []resultArtifact{
				{path: fmt.Sprintf("%s/mcp-summary.json", listingDir), compression: "none", contentType: "application/json"},
				{path: fmt.Sprintf("%s/junit.xml", listingDir), compression: "none", contentType: "application/xml"},
			}
		case "pipeline":
			pipelineID, err := req.RequireString("pipeline_id")
			if err != nil {
				ensureTracker("")
				return mcp.NewToolResultError(`pipeline_id is required when scope=pipeline.

Provide the pipeline UUID from pipelines_list. Example:
test_results_signed_url(scope="pipeline", pipeline_id="...")`), nil
			}
			pipelineID = strings.TrimSpace(pipelineID)
			if err := shared.ValidateUUID(pipelineID, "pipeline_id"); err != nil {
				ensureTracker("")
				return mcp.NewToolResultError(err.Error()), nil
			}

			pipelineResp, err := clients.DescribePipeline(ctx, api, pipelineID, false)
			if err != nil {
				ensureTracker("")
				return mcp.NewToolResultError(err.Error()), nil
			}
			pipeline := pipelineResp.GetPipeline()
			if pipeline.GetState() != pipelinepb.Pipeline_DONE {
				ensureTracker("")
				return mcp.NewToolResultError(fmt.Sprintf("pipeline is not done (current state: %s). Test results are only available after the pipeline completes. Use pipelines_describe to check pipeline status.", pipeline.GetState().String())), nil
			}
			orgID = strings.TrimSpace(pipeline.GetOrganizationId())
			projectID = strings.TrimSpace(pipeline.GetProjectId())
			pipelineWorkflowID := strings.TrimSpace(pipeline.GetWfId())
			if err := shared.ValidateUUID(orgID, "pipeline organization_id"); err != nil {
				ensureTracker("")
				return mcp.NewToolResultError(err.Error()), nil
			}
			if err := shared.ValidateUUID(projectID, "pipeline project_id"); err != nil {
				ensureTracker("")
				return mcp.NewToolResultError(err.Error()), nil
			}
			if err := shared.ValidateUUID(pipelineWorkflowID, "pipeline workflow_id"); err != nil {
				ensureTracker("")
				return mcp.NewToolResultError(err.Error()), nil
			}
			listingDir = fmt.Sprintf("artifacts/workflows/%s/test-results", pipelineWorkflowID)
			artifactCandidates = []resultArtifact{
				{path: fmt.Sprintf("%s/%s-mcp-summary.json", listingDir, pipelineID), compression: "none", contentType: "application/json"},
				{path: fmt.Sprintf("%s/%s-summary.json", listingDir, pipelineID), compression: "gzip", contentType: "application/json"},
			}
		}

		ensureTracker(orgID)

		if err := shared.EnsureReadToolsFeature(ctx, api, orgID); err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		project, err := clients.DescribeProject(ctx, api, orgID, userID, projectID)
		if err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		projectMeta := project.GetMetadata()
		projectSpec := project.GetSpec()
		projectOrgID := ""
		projectMetaID := ""
		if projectMeta != nil {
			projectOrgID = strings.TrimSpace(projectMeta.GetOrgId())
			projectMetaID = strings.TrimSpace(projectMeta.GetId())
		}

		if normalized := strings.ToLower(projectOrgID); normalized == "" || normalized != strings.ToLower(orgID) {
			shared.ReportScopeMismatch(shared.ScopeMismatchMetadata{
				Tool:              toolName,
				ResourceType:      "project",
				ResourceID:        projectID,
				RequestOrgID:      orgID,
				ResourceOrgID:     projectOrgID,
				RequestProjectID:  projectID,
				ResourceProjectID: projectMetaID,
			})
			return shared.ScopeMismatchError(toolName, "organization"), nil
		}
		if projectMetaID != "" && !sameID(projectMetaID, projectID) {
			shared.ReportScopeMismatch(shared.ScopeMismatchMetadata{
				Tool:              toolName,
				ResourceType:      "project",
				ResourceID:        projectMetaID,
				RequestOrgID:      orgID,
				ResourceOrgID:     projectOrgID,
				RequestProjectID:  projectID,
				ResourceProjectID: projectMetaID,
			})
			return shared.ScopeMismatchError(toolName, "project"), nil
		}

		projectPublic := isProjectPublic(project)
		if userID == "" && !projectPublic {
			return mcp.NewToolResultError(`Missing X-Semaphore-User-ID header.

This tool enforces project permissions before returning signed URLs. Provide the authenticated user ID (UUID) in the header, or ensure the project is public to allow guest access.`), nil
		}
		if !projectPublic {
			if err := authz.CheckProjectPermission(ctx, api, userID, orgID, projectID, projectViewPermission); err != nil {
				return shared.ProjectAuthorizationError(err, orgID, projectID, projectViewPermission), nil
			}
		}

		storeID := ""
		if projectSpec != nil {
			storeID = strings.TrimSpace(projectSpec.GetArtifactStoreId())
		}
		if storeID == "" {
			return mcp.NewToolResultError("project is missing an artifact_store_id; cannot generate signed URLs"), nil
		}

		selectedArtifact, err := resolveResultArtifact(ctx, api, storeID, listingDir, artifactCandidates)
		if err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		url, err := signedURL(ctx, api, storeID, selectedArtifact.path)
		if err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		markdown := formatResultMarkdown(scope, selectedArtifact, url)

		tracker.MarkSuccess()
		return &mcp.CallToolResult{
			Content: []mcp.Content{
				mcp.NewTextContent(markdown),
			},
			StructuredContent: map[string]string{
				"scope":        scope,
				"artifactUrl":  url,
				"path":         selectedArtifact.path,
				"compression":  selectedArtifact.compression,
				"content_type": selectedArtifact.contentType,
			},
		}, nil
	}
}

func resolveResultArtifact(ctx context.Context, api internalapi.Provider, storeID, listingDir string, candidates []resultArtifact) (resultArtifact, error) {
	if len(candidates) == 0 {
		return resultArtifact{}, fmt.Errorf("no artifact candidates configured")
	}

	items, err := listPath(ctx, api, storeID, listingDir)
	if err != nil {
		logging.ForComponent("rpc").
			WithFields(logrus.Fields{
				"rpc":        "artifacthub.ListPath",
				"artifactId": storeID,
				"path":       listingDir,
			}).
			WithError(err).
			Warn("ListPath RPC failed; falling back to preferred path without existence check")
		return candidates[0], nil
	}

	available := make(map[string]struct{}, len(items)*2)
	for _, item := range items {
		if item.GetIsDirectory() {
			continue
		}
		name := strings.TrimSpace(item.GetName())
		if name == "" {
			continue
		}
		lowerName := strings.ToLower(name)
		available[lowerName] = struct{}{}

		base := strings.ToLower(path.Base(strings.TrimSuffix(name, "/")))
		if base != "" {
			available[base] = struct{}{}
		}
	}

	for _, candidate := range candidates {
		base := strings.ToLower(path.Base(candidate.path))
		if _, ok := available[base]; ok {
			return candidate, nil
		}
	}

	return resultArtifact{}, fmt.Errorf("no test result artifacts found in `%s`. Test reports may not be configured for this project. Use the docs_search tool with query 'test reports setup' to learn how to configure test reports", strings.TrimSuffix(listingDir, "/"))
}

func listPath(ctx context.Context, api internalapi.Provider, artifactID, directory string) ([]*artifacthubpb.ListItem, error) {
	client := api.Artifacthub()
	if client == nil {
		return nil, fmt.Errorf("artifacthub gRPC endpoint is not configured")
	}

	callCtx, cancel := context.WithTimeout(ctx, api.CallTimeout())
	defer cancel()

	resp, err := client.ListPath(callCtx, &artifacthubpb.ListPathRequest{
		ArtifactId: artifactID,
		Path:       directory,
	})
	if err != nil {
		logging.ForComponent("rpc").
			WithFields(logrus.Fields{
				"rpc":        "artifacthub.ListPath",
				"artifactId": artifactID,
				"path":       directory,
			}).
			WithError(err).
			Error("ListPath RPC failed")
		return nil, fmt.Errorf("artifacthub ListPath failed: %w", err)
	}

	return resp.GetItems(), nil
}

func formatResultMarkdown(scope string, artifact resultArtifact, url string) string {
	mb := shared.NewMarkdownBuilder()
	mb.H2("Test Results URL")
	mb.KeyValue("Scope", scope)
	mb.KeyValue("Path", fmt.Sprintf("`%s`", artifact.path))
	mb.KeyValue("URL", url)
	mb.KeyValue("Compression", artifact.compression)
	mb.KeyValue("Content Type", artifact.contentType)
	mb.Line()
	mb.H3("IMPORTANT: Download once and reuse locally")
	mb.Paragraph("The signed URL expires quickly. Download the failed-test JSON to a local file and reuse it instead of fetching repeatedly.")
	mb.Line()
	mb.Paragraph("**Download command:**")
	mb.Line()
	mb.CodeBlock("bash", fmt.Sprintf(`curl -s "%s" -o %s`, url, path.Base(artifact.path)))
	mb.Line()
	mb.Paragraph(fmt.Sprintf("Then read `%s` to analyze the results.", path.Base(artifact.path)))
	return mb.String()
}

func signedURL(ctx context.Context, api internalapi.Provider, artifactID, path string) (string, error) {
	client := api.Artifacthub()
	if client == nil {
		return "", fmt.Errorf("artifacthub gRPC endpoint is not configured")
	}
	callCtx, cancel := context.WithTimeout(ctx, api.CallTimeout())
	defer cancel()

	resp, err := client.GetSignedURL(callCtx, &artifacthubpb.GetSignedURLRequest{
		ArtifactId: artifactID,
		Path:       path,
		Method:     "GET",
	})
	if err != nil {
		logging.ForComponent("rpc").
			WithFields(logrus.Fields{
				"rpc":        "artifacthub.GetSignedURL",
				"artifactId": artifactID,
				"path":       path,
			}).
			WithError(err).
			Error("GetSignedURL RPC failed")
		return "", fmt.Errorf("artifacthub GetSignedURL failed: %w", err)
	}
	url := strings.TrimSpace(resp.GetUrl())
	if url == "" {
		return "", fmt.Errorf("artifacthub GetSignedURL returned an empty url")
	}
	return url, nil
}

func sameID(a, b string) bool {
	return strings.ToLower(strings.TrimSpace(a)) == strings.ToLower(strings.TrimSpace(b))
}

func isProjectPublic(project *projecthubpb.Project) bool {
	if project == nil || project.GetSpec() == nil {
		return false
	}
	spec := project.GetSpec()
	if spec.GetVisibility() == projecthubenum.Project_Spec_PUBLIC {
		return true
	}
	return spec.GetPublic()
}
