package internalapi

import (
	"fmt"
	"log"
	"net"

	recovery "github.com/grpc-ecosystem/go-grpc-middleware/v2/interceptors/recovery"
	protos "github.com/semaphoreio/semaphore/loghub2/pkg/protos/loghub2"
	"google.golang.org/grpc"
	health "google.golang.org/grpc/health/grpc_health_v1"
)

var (
	customFunc recovery.RecoveryHandlerFunc
)

func RunServer(port int, privateKey string) {
	endpoint := fmt.Sprintf("0.0.0.0:%d", port)
	lis, err := net.Listen("tcp", endpoint)

	if err != nil {
		log.Fatalf("failed to listen: %v", err)
	}

	//
	// Set up error handler middlewares for the server.
	//
	opts := []recovery.Option{
		recovery.WithRecoveryHandler(customFunc),
	}

	grpcServer := grpc.NewServer(
		grpc.ChainUnaryInterceptor(
			recovery.UnaryServerInterceptor(opts...),
		),
		grpc.ChainStreamInterceptor(
			recovery.StreamServerInterceptor(opts...),
		),
	)

	healthService := &HealthCheckServer{}
	health.RegisterHealthServer(grpcServer, healthService)

	service := NewLoghub2Service(privateKey)
	protos.RegisterLoghub2Server(grpcServer, service)

	//
	// Start handling incomming requests
	//
	log.Printf("Starting GRPC on %s.", endpoint)
	err = grpcServer.Serve(lis)
	if err != nil {
		log.Fatalf("failed to serve: %v", err)
	}
}
