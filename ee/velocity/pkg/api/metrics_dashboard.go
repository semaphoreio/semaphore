package api

import (
	"context"
	"errors"
	"log"

	"github.com/google/uuid"
	"github.com/semaphoreio/semaphore/velocity/pkg/entity"
	pb "github.com/semaphoreio/semaphore/velocity/pkg/protos/velocity"
)

var ErrEmptyDashboardName = errors.New("empty dashboard name")

func (p velocityService) DescribeMetricsDashboard(ctx context.Context, request *pb.DescribeMetricsDashboardRequest) (*pb.DescribeMetricsDashboardResponse, error) {
	id, err := uuid.Parse(request.Id)
	if err != nil {
		return nil, err
	}

	dashboard, err := entity.FindMetricsDashboardById(id)
	if err != nil {
		if isNotFound(err) {
			return &pb.DescribeMetricsDashboardResponse{Dashboard: &pb.MetricsDashboard{}}, nil
		}
		return nil, err
	}

	return &pb.DescribeMetricsDashboardResponse{Dashboard: dashboard.ToProto()}, nil
}

func (p velocityService) ListMetricsDashboards(ctx context.Context, request *pb.ListMetricsDashboardsRequest) (*pb.ListMetricsDashboardsResponse, error) {
	projectId, err := uuid.Parse(request.ProjectId)
	if err != nil {
		return nil, err
	}

	dashboards, err := entity.ListMetricsDashboardsByProject(projectId)
	if err != nil {
		if isNotFound(err) {
			return &pb.ListMetricsDashboardsResponse{Dashboards: []*pb.MetricsDashboard{}}, nil
		}
		return nil, err
	}

	protoDashboards := make([]*pb.MetricsDashboard, 0)
	for _, dashboard := range dashboards {
		protoDashboards = append(protoDashboards, dashboard.ToProto())
	}
	return &pb.ListMetricsDashboardsResponse{Dashboards: protoDashboards}, nil
}

func (p velocityService) CreateMetricsDashboard(ctx context.Context, request *pb.CreateMetricsDashboardRequest) (*pb.CreateMetricsDashboardResponse, error) {
	var err error
	var dashboard entity.MetricsDashboard

	if len(request.Name) == 0 {
		log.Printf("CreateMetricsDashboard error: %v, request: %+v", ErrEmptyDashboardName, request)
		return nil, ErrEmptyDashboardName
	}
	dashboard.Name = request.Name
	dashboard.ProjectId, err = uuid.Parse(request.ProjectId)
	if err != nil {
		log.Printf("CreateMetricsDashboard error: %v, request: %+v", err, request)
		return nil, err
	}

	dashboard.OrganizationId, err = uuid.Parse(request.OrganizationId)
	if err != nil {
		log.Printf("CreateMetricsDashboard error: %v, request: %+v", err, request)
		return nil, err
	}

	err = entity.SaveMetricsDashboard(&dashboard)
	if err != nil {
		log.Printf("CreateMetricsDashboard error: %v, request: %+v", err, request)
		return nil, err
	}

	return &pb.CreateMetricsDashboardResponse{Dashboard: dashboard.ToProto()}, nil
}

func (p velocityService) UpdateMetricsDashboard(ctx context.Context, request *pb.UpdateMetricsDashboardRequest) (*pb.UpdateMetricsDashboardResponse, error) {
	dashboardId, err := uuid.Parse(request.Id)
	if err != nil {
		return nil, err
	}

	if len(request.Name) == 0 {
		log.Printf("UpdateMetricsDashboard error: %v, request: %+v", ErrEmptyDashboardName, request)
		return nil, ErrEmptyDashboardName
	}

	if err = entity.UpdateMetricsDashboard(dashboardId, request.Name); err != nil {
		log.Printf("UpdateMetricsDashboard error: %v, request: %+v", err, request)
		return nil, err
	}

	return &pb.UpdateMetricsDashboardResponse{}, nil
}

func (p velocityService) DeleteMetricsDashboard(ctx context.Context, request *pb.DeleteMetricsDashboardRequest) (*pb.DeleteMetricsDashboardResponse, error) {
	dashboardId, err := uuid.Parse(request.Id)
	if err != nil {
		log.Printf("DeleteMetricsDashboard error: %v, request: %+v", err, request)
		return nil, err
	}

	if err = entity.DeleteMetricsDashboardById(dashboardId); err != nil {
		log.Printf("DeleteMetricsDashboard error: %v, request: %+v", err, request)
		return nil, err
	}

	return &pb.DeleteMetricsDashboardResponse{}, nil
}
