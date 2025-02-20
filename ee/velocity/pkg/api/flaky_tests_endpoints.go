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

func (p velocityService) ListFlakyTestsFilters(ctx context.Context, request *pb.ListFlakyTestsFiltersRequest) (*pb.ListFlakyTestsFiltersResponse, error) {
	defer watchman.Benchmark(time.Now(), "velocity.pipeline_metrics.ListFlakyTestsFilters")
	id := uuid.MustParse(request.ProjectId)
	filters, err := entity.ListFlakyTestsFiltersFor(id)
	if err != nil {
		log.Printf("ListFlakyTestsFilters error: error: %v, request: %v", request, err)
		return nil, err
	}

	response := &pb.ListFlakyTestsFiltersResponse{}
	for _, filter := range filters {
		response.Filters = append(response.Filters, filter.ToProto())
	}
	return response, nil
}

func (p velocityService) CreateFlakyTestsFilter(ctx context.Context, request *pb.CreateFlakyTestsFilterRequest) (*pb.CreateFlakyTestsFilterResponse, error) {
	defer watchman.Benchmark(time.Now(), "velocity.pipeline_metrics.SaveFlakyTestsFilter")
	filter := &entity.FlakyTestsFilter{
		ProjectID:      uuid.MustParse(request.ProjectId),
		OrganizationId: uuid.MustParse(request.OrganizationId),
		Name:           request.Name,
		Value:          request.Value,
	}
	err := entity.CreateFlakyTestsFilter(filter)
	if err != nil {
		log.Printf("SaveFlakyTestsFilter error: error: %v, request: %v", request, err)
		return nil, err
	}

	response := pb.CreateFlakyTestsFilterResponse{
		Filter: filter.ToProto(),
	}
	return &response, nil
}

func (p velocityService) RemoveFlakyTestsFilter(ctx context.Context, request *pb.RemoveFlakyTestsFilterRequest) (*pb.RemoveFlakyTestsFilterResponse, error) {
	defer watchman.Benchmark(time.Now(), "velocity.pipeline_metrics.RemoveFlakyTestsFilter")
	id := uuid.MustParse(request.Id)
	err := entity.DeleteFlakyTestsFilter(id)
	if err != nil {
		log.Printf("RemoveFlakyTestsFilter error: error: %v, request: %v", request, err)
		return nil, err
	}
	return &pb.RemoveFlakyTestsFilterResponse{}, nil
}

func (p velocityService) UpdateFlakyTestsFilter(ctx context.Context, request *pb.UpdateFlakyTestsFilterRequest) (*pb.UpdateFlakyTestsFilterResponse, error) {
	defer watchman.Benchmark(time.Now(), "velocity.pipeline_metrics.UpdateFlakyTestsFilter")

	filter := &entity.FlakyTestsFilter{
		ID:    uuid.MustParse(request.Id),
		Name:  request.Name,
		Value: request.Value,
	}

	err := entity.UpdateFlakyTestsFilter(filter)
	if err != nil {
		log.Printf("UpdateFlakyTestsFilter error: error: %v, request: %v", request, err)
		return nil, err
	}

	return &pb.UpdateFlakyTestsFilterResponse{
		Filter: filter.ToProto(),
	}, nil
}
