package grpcmock

import (
	"context"
	"fmt"

	zebrapb "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/protos/server_farm.job"
)

type ZebraService struct {
}

func NewZebraService() ZebraService {
	return ZebraService{}
}

func (z ZebraService) Describe(context.Context, *zebrapb.DescribeRequest) (*zebrapb.DescribeResponse, error) {
	return nil, nil
}

var (
	listJobsResponse *zebrapb.ListResponse
	listJobsError    error
)

func MockListJobsResponse(orgID string, agentType string, jobs []*zebrapb.Job) {
	listJobsResponse = &zebrapb.ListResponse{
		Jobs: jobs,
	}
	listJobsError = nil
}

func MockListJobsError(orgID string, agentType string) {
	listJobsResponse = nil
	listJobsError = fmt.Errorf("mock error listing jobs")
}

func (z ZebraService) List(ctx context.Context, req *zebrapb.ListRequest) (*zebrapb.ListResponse, error) {
	if listJobsError != nil {
		return nil, listJobsError
	}
	if listJobsResponse != nil {
		return listJobsResponse, nil
	}
	return &zebrapb.ListResponse{}, nil
}

func (z ZebraService) ListDebugSessions(context.Context, *zebrapb.ListDebugSessionsRequest) (*zebrapb.ListDebugSessionsResponse, error) {
	return nil, nil
}

func (z ZebraService) Count(context.Context, *zebrapb.CountRequest) (*zebrapb.CountResponse, error) {
	return nil, nil
}

func (z ZebraService) CountByState(context.Context, *zebrapb.CountByStateRequest) (*zebrapb.CountByStateResponse, error) {
	counts := []*zebrapb.CountByStateResponse_CountByState{}

	counts = append(counts, &zebrapb.CountByStateResponse_CountByState{
		State: zebrapb.Job_ENQUEUED,
		Count: 1,
	})

	counts = append(counts, &zebrapb.CountByStateResponse_CountByState{
		State: zebrapb.Job_SCHEDULED,
		Count: 2,
	})

	counts = append(counts, &zebrapb.CountByStateResponse_CountByState{
		State: zebrapb.Job_STARTED,
		Count: 1,
	})

	return &zebrapb.CountByStateResponse{Counts: counts}, nil
}

func (z ZebraService) Stop(context.Context, *zebrapb.StopRequest) (*zebrapb.StopResponse, error) {
	return nil, nil
}

func (z ZebraService) TotalExecutionTime(context.Context, *zebrapb.TotalExecutionTimeRequest) (*zebrapb.TotalExecutionTimeResponse, error) {
	return nil, nil
}

func (z ZebraService) GetAgentPayload(context.Context, *zebrapb.GetAgentPayloadRequest) (*zebrapb.GetAgentPayloadResponse, error) {
	return &zebrapb.GetAgentPayloadResponse{
		Payload: `{"id": "123", "fake": "payload"}`,
	}, nil
}

func (z ZebraService) CanAttach(context.Context, *zebrapb.CanAttachRequest) (*zebrapb.CanAttachResponse, error) {
	return nil, nil
}

func (z ZebraService) CanDebug(context.Context, *zebrapb.CanDebugRequest) (*zebrapb.CanDebugResponse, error) {
	return nil, nil
}
