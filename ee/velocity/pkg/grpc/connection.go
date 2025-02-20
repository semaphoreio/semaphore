// Package grpc contains a helper function to create a grpc connection.
package grpc

import (
	"log"
	"time"

	"github.com/semaphoreio/semaphore/velocity/pkg/retry"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
)

func Conn(withEndpoint string) *grpc.ClientConn {
	var conn *grpc.ClientConn
	var err error
	connectionTask := func() error {
		conn, err = grpc.Dial(withEndpoint, grpc.WithTransportCredentials(insecure.NewCredentials()))
		return err
	}
	if err = retry.WithConstantWait(withEndpoint+" GRPC connection", 10, 10*time.Second, connectionTask); err != nil {
		log.Fatalf("failed to start connection with %s grpc: %v", withEndpoint, err)
	}
	return conn
}

const maxSendMsgSize = 64 * 1024 * 1024
const maxRecvMsgSize = 256 * 1024 * 1024

func ConnWithMaxMsgSize(withEndpoint string) *grpc.ClientConn {
	var conn *grpc.ClientConn
	var err error
	connectionTask := func() error {
		// Set the load balancing policy to round robin
		serviceConfig := `{
			"loadBalancingPolicy": "round_robin"
		}`
		conn, err = grpc.Dial(withEndpoint,
			grpc.WithTransportCredentials(insecure.NewCredentials()),
			grpc.WithDefaultCallOptions(
				grpc.MaxCallSendMsgSize(maxSendMsgSize), // Set maximum message size for sending messages
				grpc.MaxCallRecvMsgSize(maxRecvMsgSize), // Set maximum message size for receiving messages
			),
			grpc.WithDefaultServiceConfig(serviceConfig),
		)
		return err
	}
	if err = retry.WithConstantWait(withEndpoint+" GRPC connection", 10, 10*time.Second, connectionTask); err != nil {
		log.Fatalf("failed to start connection with %s grpc: %v", withEndpoint, err)
	}
	return conn
}
