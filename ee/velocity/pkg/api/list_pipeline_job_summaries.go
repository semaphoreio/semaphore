package api

import (
	"context"
	"log"
	"time"

	"github.com/renderedtext/go-watchman"
	"github.com/semaphoreio/semaphore/velocity/pkg/entity"
	pb "github.com/semaphoreio/semaphore/velocity/pkg/protos/velocity"
)

func (p velocityService) ListJobSummaries(ctx context.Context, request *pb.ListJobSummariesRequest) (*pb.ListJobSummariesResponse, error) {
	defer watchman.Benchmark(time.Now(), "velocity.pipeline_metrics.ListPipelineJobSummaries")

	summaries, err := entity.ListJobSummaries(request.JobIds)
	if err != nil {
		log.Printf("ListPipelineJobSummaries error: error: %v, request: %v", request, err)
		return nil, err
	}

	return &pb.ListJobSummariesResponse{JobSummaries: summaries.ToProto()}, nil
}
