package api

import (
	"context"
	"log"
	"time"

	"github.com/renderedtext/go-watchman"
	"github.com/semaphoreio/semaphore/velocity/pkg/entity"
	pb "github.com/semaphoreio/semaphore/velocity/pkg/protos/velocity"
)

func (p velocityService) ListPipelineSummaries(ctx context.Context, request *pb.ListPipelineSummariesRequest) (*pb.ListPipelineSummariesResponse, error) {
	defer watchman.Benchmark(time.Now(), "velocity.pipeline_metrics.ListPipelineSummaries")

	summaries, err := entity.ListPipelineSummariesBy(request.PipelineIds)
	if err != nil {
		log.Printf("ListPipelineSummaries error: error: %v, request: %v", request, err)
		return nil, err
	}

	return &pb.ListPipelineSummariesResponse{PipelineSummaries: summaries.ToProto()}, nil
}
