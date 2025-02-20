package api

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/semaphoreio/semaphore/velocity/pkg/database"
	"github.com/semaphoreio/semaphore/velocity/pkg/entity"
	pb "github.com/semaphoreio/semaphore/velocity/pkg/protos/velocity"
	"github.com/stretchr/testify/suite"
)

type VelocityServiceTestSuite struct {
	suite.Suite
}

func (s *VelocityServiceTestSuite) ListPipelineSummaries() {

	service := NewVelocityService(nil)
	database.Truncate(entity.PipelineSummary{}.TableName())
	projectID := uuid.New()
	pipelineID := uuid.New()

	ps := entity.PipelineSummary{
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

	err := entity.SavePipelineSummary(&ps)
	s.Require().Nil(err)

	response, err := service.ListPipelineSummaries(context.Background(),
		&pb.ListPipelineSummariesRequest{PipelineIds: []string{ps.PipelineID.String()}})

	s.Require().Nil(err)
	s.Require().NotNil(response)
	s.Require().Len(response.PipelineSummaries, 1)

	summary := response.PipelineSummaries[0]

	s.Equal(ps.PipelineID, summary.PipelineId)
	s.Equal(ps.Total, summary.Summary.Total)
	s.Equal(ps.Passed, summary.Summary.Passed)
	s.Equal(ps.Failed, summary.Summary.Failed)
	s.Equal(ps.Skipped, summary.Summary.Skipped)
	s.Equal(ps.Errors, summary.Summary.Error)
	s.Equal(ps.Disabled, summary.Summary.Disabled)
	s.Equal(ps.Duration, summary.Summary.Duration)
}

func (s *VelocityServiceTestSuite) ListJobSummaries() {

	service := NewVelocityService(nil)
	database.Truncate(entity.JobSummary{}.TableName())
	projectID := uuid.New()
	pipelineID := uuid.New()
	jobID := uuid.New()

	jobSummary := entity.JobSummary{
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

	err := entity.SaveJobSummary(&jobSummary)
	s.Require().Nil(err)

	response, err := service.ListJobSummaries(context.Background(),
		&pb.ListJobSummariesRequest{JobIds: []string{jobSummary.JobID.String()}})

	s.Require().Nil(err)
	s.Require().NotNil(response)
	s.Require().Len(response.JobSummaries, 1)

	summary := response.JobSummaries[0]

	s.Equal(jobSummary.PipelineID, summary.PipelineId)
	s.Equal(jobSummary.JobID, summary.JobId)
	s.Equal(jobSummary.Total, summary.Summary.Total)
	s.Equal(jobSummary.Passed, summary.Summary.Passed)
	s.Equal(jobSummary.Failed, summary.Summary.Failed)
	s.Equal(jobSummary.Skipped, summary.Summary.Skipped)
	s.Equal(jobSummary.Errors, summary.Summary.Error)
	s.Equal(jobSummary.Disabled, summary.Summary.Disabled)
	s.Equal(jobSummary.Duration, summary.Summary.Duration)
}

func TestVelocityServiceTestSuite(t *testing.T) {
	suite.Run(t, new(VelocityServiceTestSuite))
}
