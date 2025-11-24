package workflows

import "strings"

// summary represents workflow metadata returned by workflows_search.
type summary struct {
	ID              string `json:"id"`
	InitialPipeline string `json:"initialPipelineId,omitempty"`
	ProjectID       string `json:"projectId,omitempty"`
	OrganizationID  string `json:"organizationId,omitempty"`
	Branch          string `json:"branch,omitempty"`
	CommitSHA       string `json:"commitSha,omitempty"`
	RequesterID     string `json:"requesterId,omitempty"`
	TriggeredBy     string `json:"triggeredBy,omitempty"`
	CreatedAt       string `json:"createdAt,omitempty"`
	RerunOf         string `json:"rerunOf,omitempty"`
	RepositoryID    string `json:"repositoryId,omitempty"`
}

type listResult struct {
	Workflows  []summary `json:"workflows"`
	NextCursor string    `json:"nextCursor,omitempty"`
}

type runResult struct {
	WorkflowID   string `json:"workflowId"`
	PipelineID   string `json:"pipelineId"`
	Reference    string `json:"reference"`
	CommitSHA    string `json:"commitSha,omitempty"`
	PipelineFile string `json:"pipelineFile"`
}

type rerunResult struct {
	WorkflowID string `json:"workflowId"`
	PipelineID string `json:"pipelineId"`
	RerunOf    string `json:"rerunOf"`
	ProjectID  string `json:"projectId"`
	OrgID      string `json:"organizationId"`
}

func humanizeTriggeredBy(value string) string {
	value = strings.TrimSpace(value)
	if value == "" {
		return "Unspecified"
	}
	parts := strings.Split(value, "_")
	for i, part := range parts {
		if part == "" {
			continue
		}
		part = strings.ToLower(part)
		parts[i] = strings.ToUpper(part[:1]) + part[1:]
	}
	return strings.Join(parts, " ")
}

func shortenCommit(sha string) string {
	sha = strings.TrimSpace(sha)
	if len(sha) > 12 {
		return sha[:12]
	}
	return sha
}

func normalizeID(value string) string {
	return strings.ToLower(strings.TrimSpace(value))
}
