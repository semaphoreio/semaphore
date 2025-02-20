package entity

import (
	"github.com/google/uuid"
)

func MetricsDashboardFixture(name string, options ...MetricsDashboardFixtureOption) *MetricsDashboard {
	metricsDashboard := &MetricsDashboard{
		Name: name,
	}

	for _, option := range options {
		option(metricsDashboard)
	}

	if err := SaveMetricsDashboard(metricsDashboard); err != nil {
		panic(err)
	}

	return metricsDashboard
}

type MetricsDashboardFixtureOption func(*MetricsDashboard)

func WithMetricsDashboardProjectId(projectId uuid.UUID) MetricsDashboardFixtureOption {
	return func(metricsDashboard *MetricsDashboard) {
		metricsDashboard.ProjectId = projectId
	}
}

func WithMetricsDashboardOrganizationId(organizationId uuid.UUID) MetricsDashboardFixtureOption {
	return func(metricsDashboard *MetricsDashboard) {
		metricsDashboard.OrganizationId = organizationId
	}
}
