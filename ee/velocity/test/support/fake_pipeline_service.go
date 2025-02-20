// Package support defines the fake server implementation for the 3rd party services.
package support

import (
	"context"
	"math/rand"
	"time"

	"github.com/golang/protobuf/ptypes/timestamp"
	"github.com/google/uuid"
	pb "github.com/semaphoreio/semaphore/velocity/pkg/protos/plumber.pipeline"
)

type FakePipelineServiceServer struct {
	ProjectID         string
	Branches          []string
	PipelineFileNames []string
}

func (f FakePipelineServiceServer) Schedule(_ context.Context, _ *pb.ScheduleRequest) (*pb.ScheduleResponse, error) {
	panic("implement me")
}

func (f FakePipelineServiceServer) Describe(_ context.Context, request *pb.DescribeRequest) (*pb.DescribeResponse, error) {
	// #nosec
	branch := f.Branches[rand.Intn(len(f.Branches))]

	// #nosec
	yaml := f.PipelineFileNames[rand.Intn(len(f.PipelineFileNames))]

	yesterday := time.Now().Add(-1 * time.Hour * 24).Unix()
	response := pb.DescribeResponse{
		Pipeline: &pb.Pipeline{
			PplId:        request.PplId,
			Name:         "Build and Test",
			ProjectId:    f.ProjectID,
			BranchName:   branch,
			RunningAt:    &timestamp.Timestamp{Seconds: yesterday},
			DoneAt:       &timestamp.Timestamp{Seconds: yesterday},
			State:        0,
			Result:       0,
			ResultReason: 0,
			BranchId:     uuid.NewString(),
			YamlFileName: yaml,
			WfId:         uuid.NewString(),
		},
	}

	return &response, nil
}

func (f FakePipelineServiceServer) DescribeMany(_ context.Context, _ *pb.DescribeManyRequest) (*pb.DescribeManyResponse, error) {
	panic("implement me")
}

func (f FakePipelineServiceServer) DescribeTopology(_ context.Context, _ *pb.DescribeTopologyRequest) (*pb.DescribeTopologyResponse, error) {
	panic("implement me")
}

func (f FakePipelineServiceServer) Terminate(_ context.Context, _ *pb.TerminateRequest) (*pb.TerminateResponse, error) {
	panic("implement me")
}

func (f FakePipelineServiceServer) ListKeyset(_ context.Context, _ *pb.ListKeysetRequest) (*pb.ListKeysetResponse, error) {
	panic("implement me")
}

func (f FakePipelineServiceServer) List(_ context.Context, _ *pb.ListRequest) (*pb.ListResponse, error) {
	panic("implement me")
}

func (f FakePipelineServiceServer) ListGrouped(_ context.Context, _ *pb.ListGroupedRequest) (*pb.ListGroupedResponse, error) {
	panic("implement me")
}

func (f FakePipelineServiceServer) ListQueues(_ context.Context, _ *pb.ListQueuesRequest) (*pb.ListQueuesResponse, error) {
	panic("implement me")
}

func (f FakePipelineServiceServer) ListActivity(_ context.Context, _ *pb.ListActivityRequest) (*pb.ListActivityResponse, error) {
	panic("implement me")
}

func (f FakePipelineServiceServer) RunNow(_ context.Context, _ *pb.RunNowRequest) (*pb.RunNowResponse, error) {
	panic("implement me")
}

func (f FakePipelineServiceServer) GetProjectId(_ context.Context, _ *pb.GetProjectIdRequest) (*pb.GetProjectIdResponse, error) {
	panic("implement me")
}

func (f FakePipelineServiceServer) ValidateYaml(_ context.Context, _ *pb.ValidateYamlRequest) (*pb.ValidateYamlResponse, error) {
	panic("implement me")
}

func (f FakePipelineServiceServer) ScheduleExtension(_ context.Context, _ *pb.ScheduleExtensionRequest) (*pb.ScheduleExtensionResponse, error) {
	panic("implement me")
}

func (f FakePipelineServiceServer) Delete(_ context.Context, _ *pb.DeleteRequest) (*pb.DeleteResponse, error) {
	panic("implement me")
}

func (f FakePipelineServiceServer) PartialRebuild(_ context.Context, _ *pb.PartialRebuildRequest) (*pb.PartialRebuildResponse, error) {
	panic("implement me")
}

func (f FakePipelineServiceServer) Version(_ context.Context, _ *pb.VersionRequest) (*pb.VersionResponse, error) {
	panic("implement me")
}

func (f FakePipelineServiceServer) ListRequesters(_ context.Context, _ *pb.ListRequestersRequest) (*pb.ListRequestersResponse, error) {
	panic("implement me")
}
