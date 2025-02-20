package api

import (
	"context"
	health "google.golang.org/grpc/health/grpc_health_v1"
)

type healthService struct {
}

func (p healthService) Check(ctx context.Context, request *health.HealthCheckRequest) (*health.HealthCheckResponse, error) {
	return &health.HealthCheckResponse{Status: health.HealthCheckResponse_SERVING}, nil
}

func (p healthService) Watch(request *health.HealthCheckRequest, server health.Health_WatchServer) error {
	return server.Send(&health.HealthCheckResponse{Status: health.HealthCheckResponse_SERVING})
}
