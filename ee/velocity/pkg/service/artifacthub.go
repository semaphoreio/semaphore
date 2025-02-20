// Package service holds grpc service's client implementations
package service

import (
	"context"
	"time"

	"github.com/semaphoreio/semaphore/velocity/pkg/config"
	"github.com/semaphoreio/semaphore/velocity/pkg/protos/artifacthub"
	"google.golang.org/grpc"
)

type ArtifactHubGrpcClient struct {
	conn *grpc.ClientConn
}

type ArtifactHubClient interface {
	GetSignedURL(withRequest *artifacthub.GetSignedURLRequest) (*artifacthub.GetSignedURLResponse, error)
}

func NewArtifactHubService(conn *grpc.ClientConn) ArtifactHubClient {
	return &ArtifactHubGrpcClient{conn: conn}
}

func (c *ArtifactHubGrpcClient) GetSignedURL(request *artifacthub.GetSignedURLRequest) (*artifacthub.GetSignedURLResponse, error) {
	client := artifacthub.NewArtifactServiceClient(c.conn)

	tCtx, cancel := context.WithTimeout(context.Background(), config.GrpcCallTimeout()*time.Second)
	defer cancel()
	return client.GetSignedURL(tCtx, request)
}
