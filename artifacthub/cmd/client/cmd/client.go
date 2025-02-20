package cmd

import (
	"fmt"

	"github.com/semaphoreio/semaphore/artifacthub/pkg/api/descriptors/artifacthub"
	"google.golang.org/grpc"
)

var (
	conn       *grpc.ClientConn
	serverAddr string
	client     artifacthub.ArtifactServiceClient
)

func dial() {
	opts := []grpc.DialOption{grpc.WithInsecure()}
	var err error
	if conn, err = grpc.Dial(serverAddr, opts...); err != nil {
		panic(fmt.Errorf("fail to dial: %v", err))
	}
	client = artifacthub.NewArtifactServiceClient(conn)
}

func quit() {
	err := conn.Close()
	if err != nil {
		panic(fmt.Errorf("fail to close gRPC connection: %v", err))
	}
}
