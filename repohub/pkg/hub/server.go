package hub

import (
	"fmt"
	"log"
	"net"

	recovery "github.com/grpc-ecosystem/go-grpc-middleware/v2/interceptors/recovery"
	gorm "github.com/jinzhu/gorm"
	ia_repository "github.com/semaphoreio/semaphore/repohub/pkg/internal_api/repository"
	"google.golang.org/grpc"
)

//
// Main Entrypoint for the RepositoryHub server.
//

var (
	customFunc recovery.RecoveryHandlerFunc
)

func RunServer(db *gorm.DB, port int) {
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
	// Initialize services exposed by this server.
	//
	repoService := NewRepoService(db)

	ia_repository.RegisterRepositoryServiceServer(grpcServer, repoService)

	//
	// Start handling incomming requests
	//
	log.Printf("Starting GRPC on %s.", endpoint)
	err = grpcServer.Serve(lis)

	if err != nil {
		log.Panicf("Error starting GRPC server: %v", err)
	}
}
