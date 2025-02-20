package service

import (
	"fmt"

	artifacthub "github.com/semaphoreio/semaphore/velocity/pkg/protos/artifacthub"
)

type ArtifactReportFetcher struct {
	artifactHubClient ArtifactHubClient
}
type ReportFetcherClient interface {
	GetWorkflowReportSummaryURL(artifactStoreID string, workflowID string, pipelineID string) (string, error)
	GetJobReportSummaryURL(artifactStoreID string, jobID string) (string, error)
	GetJobReportURL(artifactStoreID string, jobID string) (string, error)
}

func NewReportFetcher(artifactHubClient ArtifactHubClient) ReportFetcherClient {
	return &ArtifactReportFetcher{
		artifactHubClient: artifactHubClient,
	}
}

func (r *ArtifactReportFetcher) GetWorkflowReportSummaryURL(artifactStoreID string, workflowID string, pipelineID string) (string, error) {
	return getSignedURL(r.artifactHubClient, artifactStoreID, fmt.Sprintf("artifacts/workflows/%s/test-results/%s-summary.json", workflowID, pipelineID))
}

func (r *ArtifactReportFetcher) GetJobReportSummaryURL(artifactStoreID string, jobID string) (string, error) {
	return getSignedURL(r.artifactHubClient, artifactStoreID, fmt.Sprintf("artifacts/jobs/%s/test-results/summary.json", jobID))
}

func (r *ArtifactReportFetcher) GetJobReportURL(artifactStoreID string, jobID string) (string, error) {
	return getSignedURL(r.artifactHubClient, artifactStoreID, fmt.Sprintf("artifacts/jobs/%s/test-results/junit.json", jobID))
}

func getSignedURL(artifactHubClient ArtifactHubClient, artifactStoreID string, path string) (string, error) {
	request := artifacthub.GetSignedURLRequest{
		ArtifactId: artifactStoreID,
		Path:       path,
	}

	response, err := artifactHubClient.GetSignedURL(&request)
	if err != nil {
		return "", err
	}

	return response.Url, nil
}
