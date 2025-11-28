package testresults

import (
	"context"
	"fmt"
	"strings"

	"github.com/google/uuid"
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
	"github.com/semaphoreio/semaphore/mcp_server/pkg/tools/internal/shared"
)

const (
	toolName              = "get_test_results"
	projectViewPermission = "project.view"
)

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
   get_test_results(scope="pipeline", pipeline_id="...", workflow_id="...")

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
		mcp.WithString(
			"workflow_id",
			mcp.Description("Workflow UUID that owns the pipeline (required when scope=pipeline). Get this from workflows_search. Format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx."),
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
		var path string

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
			job, err := fetchJob(ctx, api, jobID)
			if err != nil {
				ensureTracker("")
				return mcp.NewToolResultError(err.Error()), nil
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
			path = fmt.Sprintf("artifacts/jobs/%s/test-results/mcp-summary.json", jobID)
		case "pipeline":
			pipelineID, err := req.RequireString("pipeline_id")
			if err != nil {
				ensureTracker("")
				return mcp.NewToolResultError(`pipeline_id is required when scope=pipeline.

Provide the pipeline UUID from pipelines_list. Example:
test_results_signed_url(scope="pipeline", pipeline_id="...", workflow_id="...")`), nil
			}
			pipelineID = strings.TrimSpace(pipelineID)
			if err := shared.ValidateUUID(pipelineID, "pipeline_id"); err != nil {
				ensureTracker("")
				return mcp.NewToolResultError(err.Error()), nil
			}
			workflowID, err := req.RequireString("workflow_id")
			if err != nil {
				ensureTracker("")
				return mcp.NewToolResultError(`workflow_id is required when scope=pipeline.

Provide the workflow UUID from workflows_search. The pipeline must belong to this workflow. Example:
test_results_signed_url(scope="pipeline", pipeline_id="...", workflow_id="...")`), nil
			}
			workflowID = strings.TrimSpace(workflowID)
			if err := shared.ValidateUUID(workflowID, "workflow_id"); err != nil {
				ensureTracker("")
				return mcp.NewToolResultError(err.Error()), nil
			}

			pipeline, err := describePipeline(ctx, api, pipelineID)
			if err != nil {
				ensureTracker("")
				return mcp.NewToolResultError(err.Error()), nil
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
			if !sameID(pipelineWorkflowID, workflowID) {
				ensureTracker(orgID)
				shared.ReportScopeMismatch(shared.ScopeMismatchMetadata{
					Tool:              toolName,
					ResourceType:      "pipeline",
					ResourceID:        pipelineID,
					RequestOrgID:      orgID,
					ResourceOrgID:     pipeline.GetOrganizationId(),
					RequestProjectID:  projectID,
					ResourceProjectID: pipeline.GetProjectId(),
				})
				return shared.ScopeMismatchError(toolName, "workflow"), nil
			}
			path = fmt.Sprintf("artifacts/workflows/%s/test-results/mcp-summary.json", pipelineWorkflowID)
		}

		ensureTracker(orgID)

		if err := shared.EnsureReadToolsFeature(ctx, api, orgID); err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		project, err := describeProject(ctx, api, orgID, userID, projectID)
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

		url, err := signedURL(ctx, api, storeID, path)
		if err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		markdown := formatResultMarkdown(scope, path, url)

		tracker.MarkSuccess()
		return &mcp.CallToolResult{
			Content: []mcp.Content{
				mcp.NewTextContent(markdown),
			},
			StructuredContent: map[string]string{
				"scope":        scope,
				"artifactUrl":  url,
				"path":         path,
				"compression":  "none",
				"content_type": "application/json",
			},
		}, nil
	}
}

func formatResultMarkdown(scope, path, url string) string {
	mb := shared.NewMarkdownBuilder()
	mb.H2("Test Results URL")
	mb.KeyValue("Scope", scope)
	mb.KeyValue("Path", fmt.Sprintf("`%s`", path))
	mb.KeyValue("URL", url)
	mb.KeyValue("Compression", "none (plain JSON, failed tests only)")
	mb.Line()
	mb.H3("IMPORTANT: Download once and reuse locally")
	mb.Paragraph("The signed URL expires quickly. Download the failed-test JSON to a local file and reuse it instead of fetching repeatedly.")
	mb.Line()
	mb.Paragraph("**Download command:**")
	mb.Line()
	mb.CodeBlock("bash", fmt.Sprintf(`curl -s "%s" -o failed-tests.json`, url))
	mb.Line()
	mb.Paragraph("Then read `failed-tests.json` to analyze the results.")
	return mb.String()
}

func describeProject(ctx context.Context, api internalapi.Provider, orgID, userID, projectID string) (*projecthubpb.Project, error) {
	client := api.Projects()
	if client == nil {
		return nil, fmt.Errorf("project gRPC endpoint is not configured")
	}
	callCtx, cancel := context.WithTimeout(ctx, api.CallTimeout())
	defer cancel()

	req := &projecthubpb.DescribeRequest{
		Id: projectID,
		Metadata: &projecthubpb.RequestMeta{
			ApiVersion: "v1alpha",
			Kind:       "Project",
			OrgId:      strings.TrimSpace(orgID),
			UserId:     strings.TrimSpace(userID),
			ReqId:      uuid.NewString(),
		},
	}

	resp, err := client.Describe(callCtx, req)
	if err != nil {
		logging.ForComponent("rpc").
			WithFields(logrus.Fields{
				"rpc":       "project.Describe",
				"projectId": projectID,
				"orgId":     orgID,
				"userId":    userID,
			}).
			WithError(err).
			Error("describe project RPC failed")
		return nil, fmt.Errorf("describe project RPC failed: %w", err)
	}
	if err := shared.CheckProjectResponseMeta(resp.GetMetadata()); err != nil {
		return nil, err
	}
	if resp.GetProject() == nil {
		return nil, fmt.Errorf("describe project returned no project payload")
	}
	return resp.GetProject(), nil
}

func describePipeline(ctx context.Context, api internalapi.Provider, pipelineID string) (*pipelinepb.Pipeline, error) {
	client := api.Pipelines()
	if client == nil {
		return nil, fmt.Errorf("pipeline gRPC endpoint is not configured")
	}
	callCtx, cancel := context.WithTimeout(ctx, api.CallTimeout())
	defer cancel()

	resp, err := client.Describe(callCtx, &pipelinepb.DescribeRequest{PplId: pipelineID, Detailed: false})
	if err != nil {
		logging.ForComponent("rpc").
			WithFields(logrus.Fields{
				"rpc":        "pipeline.Describe",
				"pipelineId": pipelineID,
			}).
			WithError(err).
			Error("pipeline describe RPC failed")
		return nil, fmt.Errorf("pipeline describe RPC failed: %w", err)
	}
	if status := resp.GetResponseStatus(); status != nil && status.GetCode() != pipelinepb.ResponseStatus_OK {
		message := strings.TrimSpace(status.GetMessage())
		if message == "" {
			message = "pipeline describe returned non-OK status"
		}
		return nil, fmt.Errorf("pipeline describe failed: %s", message)
	}
	if resp.GetPipeline() == nil {
		return nil, fmt.Errorf("pipeline describe returned no pipeline payload")
	}
	return resp.GetPipeline(), nil
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

func fetchJob(ctx context.Context, api internalapi.Provider, jobID string) (*jobpb.Job, error) {
	client := api.Jobs()
	if client == nil {
		return nil, fmt.Errorf("job gRPC endpoint is not configured")
	}

	callCtx, cancel := context.WithTimeout(ctx, api.CallTimeout())
	defer cancel()

	resp, err := client.Describe(callCtx, &jobpb.DescribeRequest{JobId: jobID})
	if err != nil {
		logging.ForComponent("rpc").
			WithFields(logrus.Fields{
				"rpc":   "jobs.Describe",
				"jobId": jobID,
			}).
			WithError(err).
			Error("gRPC call failed")
		return nil, fmt.Errorf("describe job RPC failed: %w", err)
	}

	if err := shared.CheckResponseStatus(resp.GetStatus()); err != nil {
		return nil, err
	}

	job := resp.GetJob()
	if job == nil {
		return nil, fmt.Errorf("describe job returned no job payload")
	}

	return job, nil
}
