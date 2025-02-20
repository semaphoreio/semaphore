package internalapi

import (
	"fmt"
	"net"

	log "github.com/sirupsen/logrus"

	recovery "github.com/grpc-ecosystem/go-grpc-middleware/v2/interceptors/recovery"
	protos "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/protos/self_hosted"
	"github.com/semaphoreio/semaphore/self_hosted_hub/pkg/quotas"
	"google.golang.org/grpc"
	health "google.golang.org/grpc/health/grpc_health_v1"
)

//
// Main Entrypoint for the RepositoryHub server.
//

var (
	customFunc recovery.RecoveryHandlerFunc
)

func RunServer(port int, quotaClient *quotas.QuotaClient) {
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

	//
	// Initialize health service.
	//
	healthService := &HealthCheckServer{}
	health.RegisterHealthServer(grpcServer, healthService)

	//
	// Initialize services exposed by this server.
	//
	service := NewSelfHostedService(quotaClient)
	protos.RegisterSelfHostedAgentsServer(grpcServer, service)

	//
	// Start handling incomming requests
	//
	log.Infof("Starting GRPC on %s.", endpoint)
	err = grpcServer.Serve(lis)
	if err != nil {
		panic(err)
	}
}
