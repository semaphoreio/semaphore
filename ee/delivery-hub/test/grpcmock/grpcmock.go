package grpcmock

import (
	"net"

	repoproxypb "github.com/semaphoreio/semaphore/delivery-hub/pkg/protos/repo_proxy"
	"google.golang.org/grpc"
)

var started = false
var registry *ServiceRegistry

type ServiceRegistry struct {
	RepoProxyService *RepoProxyService
}

func Start() (*ServiceRegistry, error) {
	if started {
		return registry, nil
	}

	started = true

	// #nosec
	lis, err := net.Listen("tcp", "0.0.0.0:50052")
	if err != nil {
		return nil, err
	}

	registry = &ServiceRegistry{
		RepoProxyService: NewRepoProxyService(),
	}

	grpcServer := grpc.NewServer()
	repoproxypb.RegisterRepoProxyServiceServer(grpcServer, registry.RepoProxyService)

	go func() {
		_ = grpcServer.Serve(lis)
	}()

	return registry, nil
}
