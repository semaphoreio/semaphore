package api

import (
	"fmt"
	"log"
	"net"

	grpc_middleware "github.com/grpc-ecosystem/go-grpc-middleware"
	grpc_recovery "github.com/grpc-ecosystem/go-grpc-middleware/recovery"
	"github.com/semaphoreio/semaphore/velocity/pkg/config"
	igrpc "github.com/semaphoreio/semaphore/velocity/pkg/grpc"
	protos "github.com/semaphoreio/semaphore/velocity/pkg/protos/velocity"
	"github.com/semaphoreio/semaphore/velocity/pkg/service"
	"google.golang.org/grpc"
	health "google.golang.org/grpc/health/grpc_health_v1"
)

var (
	customFunc grpc_recovery.RecoveryHandlerFunc
)

func RunServer(port int) {
	endpoint := fmt.Sprintf("0.0.0.0:%d", port)
	lis, err := net.Listen("tcp", endpoint)

	if err != nil {
		log.Fatalf("failed to listen: %v", err)
	}

	//
	// Set up error handler middlewares for the server.
	//
	opts := []grpc_recovery.Option{
		grpc_recovery.WithRecoveryHandler(customFunc),
	}

	grpcServer := grpc.NewServer(
		grpc_middleware.WithUnaryServerChain(
			grpc_recovery.UnaryServerInterceptor(opts...),
		),
		grpc_middleware.WithStreamServerChain(
			grpc_recovery.StreamServerInterceptor(opts...),
		),
	)

	//
	// Initialize services exposed by this server.
	projectHubServiceClient := service.NewProjectHubService(igrpc.Conn(config.ProjectHubEndpoint()))

	service := NewVelocityService(projectHubServiceClient)
	health.RegisterHealthServer(grpcServer, healthService{})

	protos.RegisterPipelineMetricsServiceServer(grpcServer, service)

	//
	// Start handling incoming requests
	//
	log.Printf("Starting GRPC on %s.", endpoint)
	err = grpcServer.Serve(lis)
	if err != nil {
		log.Fatalf("failed to start server: %v", err)
	}
}
