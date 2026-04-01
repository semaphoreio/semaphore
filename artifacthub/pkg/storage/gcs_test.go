package storage

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func Test__ArtifactLifecycle_NoEnvVarsSet(t *testing.T) {
	t.Setenv("ARTIFACT_WF_RETENTION_DAYS", "")
	t.Setenv("ARTIFACT_JOB_RETENTION_DAYS", "")
	t.Setenv("ARTIFACT_PPL_RETENTION_DAYS", "")

	lifecycle := ArtifactLifecycle()

	assert.Empty(t, lifecycle.Rules)
}

func Test__ArtifactLifecycle_AllEnvVarsSet(t *testing.T) {
	t.Setenv("ARTIFACT_WF_RETENTION_DAYS", "400")
	t.Setenv("ARTIFACT_JOB_RETENTION_DAYS", "400")
	t.Setenv("ARTIFACT_PPL_RETENTION_DAYS", "400")

	lifecycle := ArtifactLifecycle()

	assert.Len(t, lifecycle.Rules, 3)
}

func Test__ArtifactLifecycle_OnlyJobAndPplSet(t *testing.T) {
	t.Setenv("ARTIFACT_WF_RETENTION_DAYS", "")
	t.Setenv("ARTIFACT_JOB_RETENTION_DAYS", "400")
	t.Setenv("ARTIFACT_PPL_RETENTION_DAYS", "400")

	lifecycle := ArtifactLifecycle()

	if assert.Len(t, lifecycle.Rules, 2) {
		assert.Equal(t, []string{"artifacts/jobs/"}, lifecycle.Rules[0].Condition.MatchesPrefix)
		assert.Equal(t, []string{"artifacts/pipelines/"}, lifecycle.Rules[1].Condition.MatchesPrefix)
	}
}

func Test__ArtifactLifecycle_ProjectNotIncluded(t *testing.T) {
	t.Setenv("ARTIFACT_WF_RETENTION_DAYS", "400")
	t.Setenv("ARTIFACT_JOB_RETENTION_DAYS", "400")
	t.Setenv("ARTIFACT_PPL_RETENTION_DAYS", "400")

	lifecycle := ArtifactLifecycle()

	if assert.Len(t, lifecycle.Rules, 3) {
		for _, rule := range lifecycle.Rules {
			assert.NotContains(t, rule.Condition.MatchesPrefix, "artifacts/projects/")
		}
	}
}

func Test__RetentionDaysFromEnv_InvalidValues(t *testing.T) {
	t.Setenv("ARTIFACT_WF_RETENTION_DAYS", "not-a-number")
	assert.Equal(t, int64(0), retentionDaysFromEnv("ARTIFACT_WF_RETENTION_DAYS"))

	t.Setenv("ARTIFACT_WF_RETENTION_DAYS", "-1")
	assert.Equal(t, int64(0), retentionDaysFromEnv("ARTIFACT_WF_RETENTION_DAYS"))

	t.Setenv("ARTIFACT_WF_RETENTION_DAYS", "0")
	assert.Equal(t, int64(0), retentionDaysFromEnv("ARTIFACT_WF_RETENTION_DAYS"))
}
