package api

import (
	"context"
	"errors"
	"log"
	"time"

	"github.com/google/uuid"
	"github.com/renderedtext/go-watchman"
	"github.com/semaphoreio/semaphore/velocity/pkg/entity"
	pb "github.com/semaphoreio/semaphore/velocity/pkg/protos/velocity"
)

var ErrEmptyDashboardItemName = errors.New("empty dashboard item name")
var ErrEmptyDashboardItemNotes = errors.New("empty dashboard item notes")

func (p velocityService) CreateDashboardItem(ctx context.Context, request *pb.CreateDashboardItemRequest) (*pb.CreateDashboardItemResponse, error) {
	if err := watchman.Benchmark(time.Now(), "velocity.pipeline_metrics.CreateDashboardItem"); err != nil {
		log.Printf("watchman beanchmark failed with error %v", err)
		err = nil
	}

	var dashboardItem entity.MetricsDashboardItem
	if len(request.Name) == 0 {
		return nil, ErrEmptyDashboardItemName
	}

	dashboardItem.Name = request.Name

	dashboardId, err := uuid.Parse(request.MetricsDashboardId)
	if err != nil {
		return nil, err
	}

	dashboardItem.MetricsDashboardID = dashboardId
	dashboardItem.BranchName = request.BranchName
	dashboardItem.PipelineFileName = request.PipelineFileName
	dashboardItem.Notes = request.Notes

	dashboardItem.Settings = entity.ItemSettings{
		Metric: request.Settings.Metric.String(),
		Goal:   request.Settings.Goal,
	}

	if err = entity.SaveMetricsDashboardItem(&dashboardItem); err != nil {
		return nil, err
	}

	return &pb.CreateDashboardItemResponse{Item: dashboardItem.ToProto()}, nil
}

func (p velocityService) UpdateDashboardItem(ctx context.Context, request *pb.UpdateDashboardItemRequest) (*pb.UpdateDashboardItemResponse, error) {
	dashboardId, err := uuid.Parse(request.Id)
	if err != nil {
		return nil, err
	}

	if len(request.Name) == 0 {
		return nil, ErrEmptyDashboardItemName
	}

	if err = entity.UpdateMetricsDashboardItem(dashboardId, request.Name); err != nil {
		return nil, err
	}

	return &pb.UpdateDashboardItemResponse{}, nil
}

func (p velocityService) DeleteDashboardItem(ctx context.Context, request *pb.DeleteDashboardItemRequest) (*pb.DeleteDashboardItemResponse, error) {
	dashboardId, err := uuid.Parse(request.Id)
	if err != nil {
		return nil, err
	}

	if err = entity.DeleteMetricsDashboardItem(dashboardId); err != nil {
		return nil, err
	}

	return &pb.DeleteDashboardItemResponse{}, nil
}

func (p velocityService) ChangeDashboardItemNotes(ctx context.Context, request *pb.ChangeDashboardItemNotesRequest) (*pb.ChangeDashboardItemNotesResponse, error) {
	itemId, err := uuid.Parse(request.Id)
	if err != nil {
		return nil, err
	}

	if len(request.Notes) == 0 {
		return nil, ErrEmptyDashboardItemNotes
	}

	if err = entity.UpdateMetricsDashboardItemNotes(itemId, request.Notes); err != nil {
		return nil, err
	}

	return &pb.ChangeDashboardItemNotesResponse{}, nil
}
