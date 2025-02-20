package api

import (
	"fmt"
	"log"
	"net"

	grpc_recovery "github.com/grpc-ecosystem/go-grpc-middleware/v2/interceptors/recovery"
	"github.com/semaphoreio/semaphore/encryptor/pkg/crypto"
	protos "github.com/semaphoreio/semaphore/encryptor/pkg/protos/encryptor"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/health/grpc_health_v1"
	"google.golang.org/grpc/status"
)

// We allow up to 8MB of data to be encrypted.
const MaxMessageSize = 1024 * 1024 * 8

func RunServer(port int, encryptor crypto.Encryptor) {
	endpoint := fmt.Sprintf("0.0.0.0:%d", port)
	lis, err := net.Listen("tcp", endpoint)

	if err != nil {
		log.Fatalf("failed to listen: %v", err)
	}

	grpcServer := grpc.NewServer(
		grpc.MaxRecvMsgSize(MaxMessageSize),
		grpc.ChainUnaryInterceptor(
			grpc_recovery.UnaryServerInterceptor(
				grpc_recovery.WithRecoveryHandler(recoveryFunc()),
			),
		),
	)

	//
	// Initialize health check service.
	//
	healthService := &HealthCheckServer{}
	grpc_health_v1.RegisterHealthServer(grpcServer, healthService)

	//
	// Initialize services exposed by this server.
	//
	service := NewEncryptorService(encryptor)
	protos.RegisterEncryptorServer(grpcServer, service)

	//
	// Start handling incomming requests
	//
	log.Printf("Starting GRPC on %s.", endpoint)
	err = grpcServer.Serve(lis)
	if err != nil {
		panic(err)
	}
}

func recoveryFunc() grpc_recovery.RecoveryHandlerFunc {
	return func(p any) (err error) {
		return status.Errorf(codes.Unknown, "panic triggered: %v", p)
	}
}
