package entity

import (
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/semaphoreio/semaphore/velocity/pkg/database"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestFindJobSummary(t *testing.T) {
	database.Truncate(JobSummary{}.TableName())
	projectID := uuid.New()
	pipelineID := uuid.New()
	jobID := uuid.New()

	s := JobSummary{
		ProjectID:  projectID,
		PipelineID: pipelineID,
		JobID:      jobID,
		Total:      10,
		Passed:     5,
		Skipped:    1,
		Errors:     1,
		Failed:     1,
		Disabled:   2,
		Duration:   time.Second * 125,
	}

	err := SaveJobSummary(&s)
	require.Nil(t, err)

	summary, err := FindJobSummary(jobID)
	require.Nil(t, err)
	assert.Equal(t, projectID, summary.ProjectID)
	assert.Equal(t, pipelineID, summary.PipelineID)
	assert.Equal(t, jobID, summary.JobID)
	assert.Equal(t, 10, summary.Total)
	assert.Equal(t, 5, summary.Passed)
	assert.Equal(t, 1, summary.Skipped)
	assert.Equal(t, 1, summary.Errors)
	assert.Equal(t, 1, summary.Failed)
	assert.Equal(t, 2, summary.Disabled)
	assert.Equal(t, 125*time.Second, summary.Duration)
}

func TestListJobSummariesByProject(t *testing.T) {
	database.Truncate(JobSummary{}.TableName())
	projectID := uuid.New()

	s := JobSummary{
		ProjectID:  projectID,
		PipelineID: uuid.New(),
		JobID:      uuid.New(),
		Total:      10,
		Passed:     5,
		Skipped:    1,
		Errors:     1,
		Failed:     1,
		Disabled:   2,
		Duration:   time.Second * 125,
	}

	p := JobSummary{
		ProjectID:  projectID,
		PipelineID: uuid.New(),
		JobID:      uuid.New(),
		Total:      100,
		Passed:     50,
		Skipped:    10,
		Errors:     10,
		Failed:     10,
		Disabled:   20,
		Duration:   time.Minute * 3,
	}

	err := SaveJobSummary(&s)
	require.Nil(t, err)

	err = SaveJobSummary(&p)
	require.Nil(t, err)

	summaries, err := ListJobSummariesByProject(projectID)
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

func TestSaveJobSummary(t *testing.T) {
	database.Truncate(JobSummary{}.TableName())
	projectID := uuid.New()
	pipelineID := uuid.New()
	jobID := uuid.New()

	s1 := JobSummary{
		ProjectID:  projectID,
		PipelineID: pipelineID,
		JobID:      jobID,
		Total:      10,
		Passed:     5,
		Skipped:    1,
		Errors:     1,
		Failed:     1,
		Disabled:   2,
		Duration:   time.Second * 125,
	}

	s2 := JobSummary{
		ProjectID:  projectID,
		PipelineID: pipelineID,
		JobID:      jobID,
		Total:      5,
		Passed:     4,
		Skipped:    1,
		Errors:     0,
		Failed:     0,
		Disabled:   0,
		Duration:   time.Second * 300,
	}

	err := SaveJobSummary(&s1)
	require.Nil(t, err)

	err = SaveJobSummary(&s2)
	assert.NotNil(t, err)
	assert.Equal(t, "job id must be unique for a specific project", err.Error())
}

func TestListJobSummaries(t *testing.T) {
	database.Truncate(JobSummary{}.TableName())
	projectID := uuid.New()
	pipelineID := uuid.New()
	jobID := uuid.New()

	s := JobSummary{
		ProjectID:  projectID,
		PipelineID: pipelineID,
		JobID:      jobID,
		Total:      10,
		Passed:     5,
		Skipped:    1,
		Errors:     1,
		Failed:     1,
		Disabled:   2,
		Duration:   time.Second * 125,
	}

	err := SaveJobSummary(&s)
	require.Nil(t, err)

	summaries, err := ListJobSummaries([]string{jobID.String()})
	require.Nil(t, err)
	require.Len(t, summaries, 1)

	summary := summaries[0]

	assert.Equal(t, projectID, summary.ProjectID)
	assert.Equal(t, pipelineID, summary.PipelineID)
	assert.Equal(t, jobID, summary.JobID)
	assert.Equal(t, 10, summary.Total)
	assert.Equal(t, 5, summary.Passed)
	assert.Equal(t, 1, summary.Skipped)
	assert.Equal(t, 1, summary.Errors)
	assert.Equal(t, 1, summary.Failed)
	assert.Equal(t, 2, summary.Disabled)
	assert.Equal(t, 125*time.Second, summary.Duration)
}

func TestListJobSummariesByPipeline(t *testing.T) {
	database.Truncate(JobSummary{}.TableName())
	projectID := uuid.New()
	pipelineID := uuid.New()
	jobID := uuid.New()
	job2ID := uuid.New()

	js1 := JobSummary{
		ProjectID:  projectID,
		PipelineID: pipelineID,
		JobID:      jobID,
		Total:      10,
		Passed:     5,
		Skipped:    1,
		Errors:     1,
		Failed:     1,
		Disabled:   2,
		Duration:   time.Second * 125,
	}

	js2 := JobSummary{
		ProjectID:  projectID,
		PipelineID: pipelineID,
		JobID:      job2ID,
		Total:      10,
		Passed:     5,
		Skipped:    1,
		Errors:     1,
		Failed:     1,
		Disabled:   2,
		Duration:   time.Second * 125,
	}

	err := SaveJobSummary(&js1)
	require.Nil(t, err)
	err = SaveJobSummary(&js2)
	require.Nil(t, err)

	summaries, err := ListJobSummariesByPipeline(pipelineID)
	require.Nil(t, err)
	require.Len(t, summaries, 2)

	summary := summaries[0]

	assert.Equal(t, projectID, summary.ProjectID)
	assert.Equal(t, pipelineID, summary.PipelineID)
	assert.Equal(t, jobID, summary.JobID)
	assert.Equal(t, 10, summary.Total)
	assert.Equal(t, 5, summary.Passed)
	assert.Equal(t, 1, summary.Skipped)
	assert.Equal(t, 1, summary.Errors)
	assert.Equal(t, 1, summary.Failed)
	assert.Equal(t, 2, summary.Disabled)
	assert.Equal(t, 125*time.Second, summary.Duration)

	summary2 := summaries[1]

	assert.Equal(t, projectID, summary2.ProjectID)
	assert.Equal(t, pipelineID, summary2.PipelineID)
	assert.Equal(t, job2ID, summary2.JobID)
	assert.Equal(t, 10, summary2.Total)
	assert.Equal(t, 5, summary2.Passed)
	assert.Equal(t, 1, summary2.Skipped)
	assert.Equal(t, 1, summary2.Errors)
	assert.Equal(t, 1, summary2.Failed)
	assert.Equal(t, 2, summary2.Disabled)
	assert.Equal(t, 125*time.Second, summary2.Duration)
}

func TestListNonExistentJobSummariesByProject(t *testing.T) {
	database.Truncate(JobSummary{}.TableName())
	projectID := uuid.New()
	summaries, err := ListJobSummariesByProject(projectID)

	require.Nil(t, err, "does not fail when there are no summaries")
	require.Empty(t, summaries, "returns empty list of summaries")
}

func TestListNonExistentJobSummariesByPipeline(t *testing.T) {
	database.Truncate(JobSummary{}.TableName())
	pipelineID := uuid.New()
	summaries, err := ListJobSummariesByPipeline(pipelineID)

	require.Nil(t, err, "does not fail when there are no summaries")
	require.Empty(t, summaries, "returns empty list of summaries")
}

func TestListNonExistentJobSummaries(t *testing.T) {
	database.Truncate(JobSummary{}.TableName())
	jobIDs := []string{}
	for i := 0; i < 10; i++ {
		jobIDs = append(jobIDs, uuid.New().String())
	}

	summaries, err := ListJobSummaries(jobIDs)

	require.Nil(t, err, "does not fail when there are no summaries")
	require.Empty(t, summaries, "returns empty list of summaries")
}
