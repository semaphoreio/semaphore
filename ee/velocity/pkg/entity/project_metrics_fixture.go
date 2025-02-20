package entity

import (
	"time"

	"github.com/google/uuid"
)

func ProjectMetricFixture(options ...ProjectMetricFixtureOption) *ProjectMetrics {
	projectMetric := &ProjectMetrics{}

	for _, option := range options {
		option(projectMetric)
	}

	if err := SaveProjectMetrics(projectMetric); err != nil {
		panic(err)
	}

	return projectMetric
}

type ProjectMetricFixtureOption func(*ProjectMetrics)

func WithProjectMetricProjectId(projectId uuid.UUID) ProjectMetricFixtureOption {
	return func(projectMetric *ProjectMetrics) {
		projectMetric.ProjectId = projectId
	}
}

func WithProjectMetricOrganizationId(organizationId uuid.UUID) ProjectMetricFixtureOption {
	return func(projectMetric *ProjectMetrics) {
		projectMetric.OrganizationId = organizationId
	}
}

func WithProjectMetricPipelineFileName(pipelineFileName string) ProjectMetricFixtureOption {
	return func(projectMetric *ProjectMetrics) {
		projectMetric.PipelineFileName = pipelineFileName
	}
}

func WithProjectMetricBranchName(branchName string) ProjectMetricFixtureOption {
	return func(projectMetric *ProjectMetrics) {
		projectMetric.BranchName = branchName
	}
}

func WithProjectMetricCollectedAt(collectedAt time.Time) ProjectMetricFixtureOption {
	return func(projectMetric *ProjectMetrics) {
		projectMetric.CollectedAt = collectedAt
	}
}
