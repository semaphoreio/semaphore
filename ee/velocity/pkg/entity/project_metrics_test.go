package entity

import (
	"math/rand"
	"sort"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/semaphoreio/semaphore/velocity/pkg/database"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestDeleteByOrganizationId(t *testing.T) {
	database.Truncate(ProjectMetrics{}.TableName())
	projectId := uuid.New()
	now := time.Now()
	orgId := uuid.New()

	s1 := ProjectMetrics{
		ProjectId:        projectId,
		PipelineFileName: "semaphore.yml",
		CollectedAt:      now,
		BranchName:       "",
		OrganizationId:   orgId,
		Metrics:          Metrics{},
	}

	s2 := ProjectMetrics{
		ProjectId:        projectId,
		PipelineFileName: "semaphore.yml",
		CollectedAt:      now.Add(24 * time.Hour),
		BranchName:       "",
		OrganizationId:   orgId,
		Metrics:          Metrics{},
	}

	s3 := ProjectMetrics{
		ProjectId:        uuid.New(),
		PipelineFileName: "semaphore.yml",
		CollectedAt:      now.Add(24 * time.Hour),
		BranchName:       "",
		OrganizationId:   uuid.New(),
		Metrics:          Metrics{},
	}

	err := SaveProjectMetrics(&s1)
	require.Nil(t, err)

	err = SaveProjectMetrics(&s2)
	require.Nil(t, err)

	err = SaveProjectMetrics(&s3)
	require.Nil(t, err)

	err = DeleteByOrganizationId(orgId)
	require.Nil(t, err)

	var count int64
	database.Conn().Model(ProjectMetrics{}).Count(&count)
	assert.Equal(t, int64(1), count)

}

func TestSaveProjectMetrics(t *testing.T) {
	database.Truncate(ProjectMetrics{}.TableName())
	projectId := uuid.New()
	now := time.Now()

	s1 := ProjectMetrics{
		ProjectId:        projectId,
		PipelineFileName: "semaphore.yml",
		CollectedAt:      now,
		BranchName:       "",
		Metrics:          Metrics{},
	}

	s2 := ProjectMetrics{
		ProjectId:        projectId,
		PipelineFileName: "semaphore.yml",
		CollectedAt:      now,
		BranchName:       "",
		Metrics:          Metrics{},
	}

	err := SaveProjectMetrics(&s1)
	require.Nil(t, err)

	err = SaveProjectMetrics(&s2)
	assert.NotNil(t, err)
	assert.Equal(t, "cannot save the same project metric twice", err.Error())
}

func TestListPipelineFiles(t *testing.T) {
	database.Truncate(ProjectMetrics{}.TableName())
	projectID := uuid.New()
	orgID := uuid.New()

	pipelineFileNames := []string{
		".semaphore/publish-documentation.yml",
		".semaphore/dispatch-app/entry.yml",
		".semaphore/external-integration.yml",
		".semaphore/dev.yml",
		".semaphore/__popit.foxford.ru.yml",
		"pipelines/private-registry.yml",
		".semaphore/push-images/packetcapture.yml",
		"platform/core/deployment/promote-live.yml",
		".semaphore/build-push-dev-container.yml",
		".semaphore/aws-deployment.yml",
		".ci/semaphore-deploy-staging.yml",
		".semaphore/prod-api-heroku.yml",
		".semaphore/windows-containerd.yml",
		".semaphore/scaling-dogfood-deploy.yml",
		".semaphore/deploy/provider/staging1.yml",
		".semaphore/dev-nginx-build.yml",
		".semaphore/regression.yml",
		".semaphore/deploy-demo.yml",
		".semaphore/build-deploy-dev.yml",
		".semaphore/schmuckmuseum.yml",
		".semaphore/update-create-ui.yml",
		".semaphore/cloudfront-deploy.yml",
	}

	for i := 0; i <= 100; i++ {
		daysAgo := time.Now().AddDate(0, 0, -i)
		pipelineFileName := pipelineFileNames[rand.Intn(len(pipelineFileNames))]
		ProjectMetricFixture(
			WithProjectMetricProjectId(uuid.New()),
			WithProjectMetricOrganizationId(uuid.New()),
			WithProjectMetricPipelineFileName(pipelineFileName),
			WithProjectMetricCollectedAt(daysAgo),
		)
	}

	selectedPipelineFileNames := pipelineFileNames[rand.Intn(len(pipelineFileNames)):]
	sort.Strings(selectedPipelineFileNames)

	for i := 0; i <= 100; i++ {
		daysAgo := time.Now().AddDate(0, 0, -i)
		selectedFileName := selectedPipelineFileNames[i%len(selectedPipelineFileNames)]

		ProjectMetricFixture(
			WithProjectMetricProjectId(projectID),
			WithProjectMetricOrganizationId(orgID),
			WithProjectMetricPipelineFileName(selectedFileName),
			WithProjectMetricCollectedAt(daysAgo),
		)
	}

	pipelineFiles, err := ListPipelineFiles(projectID)
	sort.Strings(pipelineFiles)

	require.Nil(t, err)
	assert.Equal(t, len(pipelineFiles), len(selectedPipelineFileNames))
	assert.Equal(t, pipelineFiles, selectedPipelineFileNames)

	pipelineFiles, err = ListPipelineFiles(uuid.New())
	require.Nil(t, err)
	assert.Equal(t, len(pipelineFiles), 0)
	assert.Equal(t, pipelineFiles, []string{})
}

func TestProjectMetricsExists(t *testing.T) {
	database.Truncate(ProjectMetrics{}.TableName())
	projectID := uuid.New()
	orgID := uuid.New()
	now := time.Now()
	fileName := ".semaphore/semaphore.yml"

	exists, err := ProjectMetricsExists(ProjectMetricsKey{
		ProjectId:   projectID,
		FileName:    fileName,
		CollectedAt: now,
	})
	require.Nil(t, err)
	require.Equal(t, false, exists)

	ProjectMetricFixture(
		WithProjectMetricProjectId(projectID),
		WithProjectMetricOrganizationId(orgID),
		WithProjectMetricPipelineFileName(fileName),
		WithProjectMetricCollectedAt(now),
	)

	exists, err = ProjectMetricsExists(ProjectMetricsKey{
		ProjectId:   projectID,
		FileName:    fileName,
		CollectedAt: now,
	})
	require.Nil(t, err)
	require.Equal(t, true, exists)
}

func TestSelectOrganizationIdsWithMetricsWithinLast30Days(t *testing.T) {
	database.Truncate(ProjectMetrics{}.TableName())
	projectID := uuid.New()
	orgID := uuid.New()
	for i := 0; i <= 100; i++ {
		daysAgo := time.Now().AddDate(0, 0, -i)
		ProjectMetricFixture(
			WithProjectMetricProjectId(projectID),
			WithProjectMetricOrganizationId(uuid.New()),
			WithProjectMetricPipelineFileName(".semaphore/semaphore.yml"),
			WithProjectMetricCollectedAt(daysAgo),
		)
	}

	ProjectMetricFixture(
		WithProjectMetricProjectId(uuid.New()),
		WithProjectMetricOrganizationId(orgID),
		WithProjectMetricPipelineFileName(".semaphore/semaphore.yml"),
		WithProjectMetricCollectedAt(time.Now()),
	)

	uuids, err := SelectOrganizationIDsWithMetricsWithinLast30Days()
	require.Nil(t, err)
	assert.Equal(t, 32, len(uuids))
	assert.Contains(t, uuids, orgID)

}
