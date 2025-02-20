package api

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/renderedtext/go-watchman"
	"github.com/semaphoreio/semaphore/velocity/pkg/entity"
	pb "github.com/semaphoreio/semaphore/velocity/pkg/protos/velocity"
)

func (p velocityService) DescribeDashboardItem(ctx context.Context, request *pb.DescribeDashboardItemRequest) (*pb.DescribeDashboardItemResponse, error) {
	defer watchman.Benchmark(time.Now(), "velocity.pipeline_metrics.DescribeDashboardItem")

	id, err := uuid.Parse(request.Id)
	if err != nil {
		return nil, err
	}

	item, err := entity.DashboardItemFindById(id)
	if err != nil {
		return nil, err
	}

	return &pb.DescribeDashboardItemResponse{Item: item.ToProto()}, nil

}
