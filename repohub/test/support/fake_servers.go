package testsupport

import (
	"log"
	"net"
	"time"

	ia_projecthub "github.com/semaphoreio/semaphore/repohub/pkg/internal_api/projecthub"
	ia_repository_integrator "github.com/semaphoreio/semaphore/repohub/pkg/internal_api/repository_integrator"
	ia_user "github.com/semaphoreio/semaphore/repohub/pkg/internal_api/user"

	"google.golang.org/grpc"
)

func StartFakeServers() *grpc.Server {
	lis, err := net.Listen("tcp", "127.0.0.1:8888")

	if err != nil {
		log.Fatalf("failed to listen: %v", err)
	}

	grpcServer := grpc.NewServer()

	ia_projecthub.RegisterProjectServiceServer(grpcServer, &FakeProjectService{})
	ia_user.RegisterUserServiceServer(grpcServer, &FakeUserService{})
	ia_repository_integrator.RegisterRepositoryIntegratorServiceServer(grpcServer, &FakeRepositoryIntegratorService{})

	go func() {
		err = grpcServer.Serve(lis)
		if err != nil {
			log.Panicf("Error starting GRPC server: %v", err)
		}
	}()

	time.Sleep(3 * time.Second) // Give some time for the server to start
	return grpcServer
}
