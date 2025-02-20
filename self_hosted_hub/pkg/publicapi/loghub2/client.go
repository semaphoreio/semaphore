package loghub2

import (
	"context"

	config "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/config"
	pb "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/protos/loghub2"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
)

func GenerateToken(jobID string) (string, error) {
	conn, err := grpc.NewClient(config.Loghub2Endpoint(), grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		return "", err
	}

	defer conn.Close()

	client := pb.NewLoghub2Client(conn)
	req := pb.GenerateTokenRequest{JobId: jobID, Type: pb.TokenType_PUSH}

	res, err := client.GenerateToken(context.Background(), &req)
	if err != nil {
		return "", err
	}

	return res.Token, nil
}
