package api

import (
	"context"
	"log"
	"time"

	"github.com/google/uuid"
	"github.com/renderedtext/go-watchman"
	"github.com/semaphoreio/semaphore/velocity/pkg/entity"
	pb "github.com/semaphoreio/semaphore/velocity/pkg/protos/velocity"
)

func (p velocityService) InitializeFlakyTestsFilters(ctx context.Context, request *pb.InitializeFlakyTestsFiltersRequest) (*pb.InitializeFlakyTestsFiltersResponse, error) {
	defer watchman.Benchmark(time.Now(), "velocity.pipeline_metrics.InitializeFlakyTestsFilters")
	log.Printf("InitializeFlakyTestsFilters for Project %v", request.ProjectId)

	filters, err := entity.InitializeFlakyTestsFilters(uuid.MustParse(request.ProjectId), uuid.MustParse(request.OrganizationId))
	if err != nil {
		log.Printf("Failed to initialize flaky tests filters %v with %v", request.ProjectId, err)
		return nil, err
	}

	protoFilters := make([]*pb.FlakyTestsFilter, 0, len(filters))
	for _, filter := range filters {
		protoFilters = append(protoFilters, filter.ToProto())
	}

	return &pb.InitializeFlakyTestsFiltersResponse{Filters: protoFilters}, nil
}
