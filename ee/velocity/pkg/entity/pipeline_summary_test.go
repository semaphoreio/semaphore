package entity

import (
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/semaphoreio/semaphore/velocity/pkg/database"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestFindPipelineSummary(t *testing.T) {
	database.Truncate(PipelineSummary{}.TableName())
	projectID := uuid.New()
	pipelineID := uuid.New()

	s := PipelineSummary{
		ProjectID:  projectID,
		PipelineID: pipelineID,
		Total:      10,
		Passed:     5,
		Skipped:    1,
		Errors:     1,
		Failed:     1,
		Disabled:   2,
		Duration:   time.Second * 125,
	}

	err := SavePipelineSummary(&s)
	require.Nil(t, err)

	summary, err := FindPipelineSummary(pipelineID)
	require.Nil(t, err)
	assert.Equal(t, projectID, summary.ProjectID)
	assert.Equal(t, pipelineID, summary.PipelineID)
	assert.Equal(t, 10, summary.Total)
	assert.Equal(t, 5, summary.Passed)
	assert.Equal(t, 1, summary.Skipped)
	assert.Equal(t, 1, summary.Errors)
	assert.Equal(t, 1, summary.Failed)
	assert.Equal(t, 2, summary.Disabled)
	assert.Equal(t, 125*time.Second, summary.Duration)
}

func TestListPipelineSummaries(t *testing.T) {
	database.Truncate(PipelineSummary{}.TableName())
	projectID := uuid.New()

	s := PipelineSummary{
		ProjectID:  projectID,
		PipelineID: uuid.New(),
		Total:      10,
		Passed:     5,
		Skipped:    1,
		Errors:     1,
		Failed:     1,
		Disabled:   2,
		Duration:   time.Second * 125,
	}

	p := PipelineSummary{
		ProjectID:  projectID,
		PipelineID: uuid.New(),
		Total:      100,
		Passed:     50,
		Skipped:    10,
		Errors:     10,
		Failed:     10,
		Disabled:   20,
		Duration:   time.Minute * 3,
	}

	err := SavePipelineSummary(&s)
	require.Nil(t, err)

	err = SavePipelineSummary(&p)
	require.Nil(t, err)

	summaries, err := ListPipelineSummaries(projectID)
	require.Nil(t, err)
	require.NotEmpty(t, summaries)
	require.Len(t, summaries, 2)

	firstSummary := summaries[0]
	assert.Equal(t, projectID, firstSummary.ProjectID)
	assert.Equal(t, 10, firstSummary.Total)
	assert.Equal(t, 5, firstSummary.Passed)
	assert.Equal(t, 1, firstSummary.Skipped)
	assert.Equal(t, 1, firstSummary.Errors)
	assert.Equal(t, 1, firstSummary.Failed)
	assert.Equal(t, 2, firstSummary.Disabled)
	assert.Equal(t, 125*time.Second, firstSummary.Duration)

	secondSummary := summaries[1]
	assert.Equal(t, projectID, secondSummary.ProjectID)
	assert.Equal(t, 100, secondSummary.Total)
	assert.Equal(t, 50, secondSummary.Passed)
	assert.Equal(t, 10, secondSummary.Skipped)
	assert.Equal(t, 10, secondSummary.Errors)
	assert.Equal(t, 10, secondSummary.Failed)
	assert.Equal(t, 20, secondSummary.Disabled)
	assert.Equal(t, 3*time.Minute, secondSummary.Duration)
}

func TestSavePipelineSummary(t *testing.T) {
	database.Truncate(PipelineSummary{}.TableName())
	projectID := uuid.New()
	pipelineID := uuid.New()

	s1 := PipelineSummary{
		ProjectID:  projectID,
		PipelineID: pipelineID,
		Total:      10,
		Passed:     5,
		Skipped:    1,
		Errors:     1,
		Failed:     1,
		Disabled:   2,
		Duration:   time.Second * 125,
	}

	s2 := PipelineSummary{
		ProjectID:  projectID,
		PipelineID: pipelineID,
		Total:      5,
		Passed:     4,
		Skipped:    1,
		Errors:     0,
		Failed:     0,
		Disabled:   0,
		Duration:   time.Second * 300,
	}

	err := SavePipelineSummary(&s1)
	require.Nil(t, err)

	err = SavePipelineSummary(&s2)
	assert.NotNil(t, err)
	assert.Equal(t, "pipeline id must by unique for a specific project", err.Error())
}

func TestListPipelineSummariesBy(t *testing.T) {
	database.Truncate(PipelineSummary{}.TableName())
	projectID := uuid.New()
	pipelineID := uuid.New()

	s := PipelineSummary{
		ProjectID:  projectID,
		PipelineID: pipelineID,
		Total:      10,
		Passed:     5,
		Skipped:    1,
		Errors:     1,
		Failed:     1,
		Disabled:   2,
		Duration:   time.Second * 125,
	}

	err := SavePipelineSummary(&s)
	require.Nil(t, err)

	summaries, err := ListPipelineSummariesBy([]string{pipelineID.String()})
	require.Nil(t, err)
	require.Len(t, summaries, 1)

	summary := summaries[0]

	assert.Equal(t, projectID, summary.ProjectID)
	assert.Equal(t, pipelineID, summary.PipelineID)
	assert.Equal(t, 10, summary.Total)
	assert.Equal(t, 5, summary.Passed)
	assert.Equal(t, 1, summary.Skipped)
	assert.Equal(t, 1, summary.Errors)
	assert.Equal(t, 1, summary.Failed)
	assert.Equal(t, 2, summary.Disabled)
	assert.Equal(t, 125*time.Second, summary.Duration)
}

func Test__ListNonExistentPipelineSummaries(t *testing.T) {
	database.Truncate(PipelineSummary{}.TableName())
	projectID := uuid.New()
	summaries, err := ListPipelineSummaries(projectID)

	require.Nil(t, err, "does not fail when there are no summaries")
	require.Empty(t, summaries, "returns empty list of summaries")
}

func Test__ListNonExistentPipelineSummariesBy(t *testing.T) {
	database.Truncate(PipelineSummary{}.TableName())
	pipelineIDs := []string{}
	for i := 0; i < 10; i++ {
		pipelineIDs = append(pipelineIDs, uuid.New().String())
	}

	summaries, err := ListPipelineSummariesBy(pipelineIDs)

	require.Nil(t, err, "does not fail when there are no summaries")
	require.Empty(t, summaries, "returns empty list of summaries")
}
