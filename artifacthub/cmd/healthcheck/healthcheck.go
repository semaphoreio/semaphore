package main

import (
	"context"
	"flag"
	"fmt"

	"github.com/semaphoreio/semaphore/artifacthub/pkg/api/descriptors/artifacthub"
	"google.golang.org/grpc"
)

const defEndpoint = "0.0.0.0:50051"

var (
	serverAddr = flag.String("endpoint", defEndpoint,
		"The private server address in the format of host:port")
)

func main() {
	flag.Parse()
	opts := []grpc.DialOption{grpc.WithInsecure()}
	conn, err := grpc.Dial(*serverAddr, opts...)
	if err != nil {
		panic(fmt.Errorf("fail to dial: %v", err))
	}
	client := artifacthub.NewArtifactServiceClient(conn)
	request := &artifacthub.HealthCheckRequest{}
	ctx := context.Background()
	_, err = client.HealthCheck(ctx, request)
	if err != nil {
		panic(fmt.Errorf("healthcheck error: %v", err))
	}
}
