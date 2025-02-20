package grpcmock

import (
	"net"

	featurepb "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/protos/feature"
	loghub2pb "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/protos/loghub2"
	zebrapb "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/protos/server_farm.job"
	"google.golang.org/grpc"
)

var started = false

func Start() {
	if started {
		return
	}

	started = true

	// #nosec
	lis, err := net.Listen("tcp", "0.0.0.0:50052")
	if err != nil {
		panic(err)
	}

	grpcServer := grpc.NewServer()

	zebrapb.RegisterJobServiceServer(grpcServer, NewZebraService())
	loghub2pb.RegisterLoghub2Server(grpcServer, NewLoghub2Service())
	featurepb.RegisterFeatureServiceServer(grpcServer, NewFeatureService())

	go func() {
		_ = grpcServer.Serve(lis)
	}()
}
