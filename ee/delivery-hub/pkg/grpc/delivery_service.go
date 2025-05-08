package grpc

import (
	"context"

	"github.com/semaphoreio/semaphore/delivery-hub/pkg/encryptor"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/grpc/actions"
	pb "github.com/semaphoreio/semaphore/delivery-hub/pkg/protos/delivery"
)

type DeliveryService struct {
	encryptor encryptor.Encryptor
}

func NewDeliveryService(encryptor encryptor.Encryptor) *DeliveryService {
	return &DeliveryService{
		encryptor: encryptor,
	}
}

func (s *DeliveryService) CreateCanvas(ctx context.Context, req *pb.CreateCanvasRequest) (*pb.CreateCanvasResponse, error) {
	return actions.CreateCanvas(ctx, req)
}

func (s *DeliveryService) DescribeCanvas(ctx context.Context, req *pb.DescribeCanvasRequest) (*pb.DescribeCanvasResponse, error) {
	return actions.DescribeCanvas(ctx, req)
}

func (s *DeliveryService) CreateEventSource(ctx context.Context, req *pb.CreateEventSourceRequest) (*pb.CreateEventSourceResponse, error) {
	return actions.CreateEventSource(ctx, s.encryptor, req)
}

func (s *DeliveryService) DescribeEventSource(ctx context.Context, req *pb.DescribeEventSourceRequest) (*pb.DescribeEventSourceResponse, error) {
	return actions.DescribeEventSource(ctx, req)
}

func (s *DeliveryService) CreateStage(ctx context.Context, req *pb.CreateStageRequest) (*pb.CreateStageResponse, error) {
	return actions.CreateStage(ctx, req)
}

func (s *DeliveryService) DescribeStage(ctx context.Context, req *pb.DescribeStageRequest) (*pb.DescribeStageResponse, error) {
	return actions.DescribeStage(ctx, req)
}

func (s *DeliveryService) UpdateStage(ctx context.Context, req *pb.UpdateStageRequest) (*pb.UpdateStageResponse, error) {
	return actions.UpdateStage(ctx, req)
}

func (s *DeliveryService) ApproveStageEvent(ctx context.Context, req *pb.ApproveStageEventRequest) (*pb.ApproveStageEventResponse, error) {
	return actions.ApproveStageEvent(ctx, req)
}

func (s *DeliveryService) ListEventSources(ctx context.Context, req *pb.ListEventSourcesRequest) (*pb.ListEventSourcesResponse, error) {
	return actions.ListEventSources(ctx, req)
}

func (s *DeliveryService) ListStages(ctx context.Context, req *pb.ListStagesRequest) (*pb.ListStagesResponse, error) {
	return actions.ListStages(ctx, req)
}

func (s *DeliveryService) ListStageEvents(ctx context.Context, req *pb.ListStageEventsRequest) (*pb.ListStageEventsResponse, error) {
	return actions.ListStageEvents(ctx, req)
}
