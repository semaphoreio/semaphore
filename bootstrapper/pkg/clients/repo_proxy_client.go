package clients

import (
	"context"
	"time"

	"github.com/semaphoreio/semaphore/bootstrapper/pkg/config"
	"github.com/semaphoreio/semaphore/bootstrapper/pkg/protos/repository_integrator"
	log "github.com/sirupsen/logrus"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
)

type RepoProxyClient struct {
	client repository_integrator.RepositoryIntegratorServiceClient
}

func NewRepoProxyClient() *RepoProxyClient {
	conn, err := grpc.NewClient(config.RepoProxyEndpoint(), grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		log.Fatalf("Failed to connect to repo proxy service: %v", err)
	}

	client := repository_integrator.NewRepositoryIntegratorServiceClient(conn)
	return &RepoProxyClient{client: client}
}

func (c *RepoProxyClient) InitGithubApplication() error {
	ctx, cancel := context.WithTimeout(context.Background(), time.Second*10)
	defer cancel()

	_, err := c.client.InitGithubInstallation(ctx, &repository_integrator.InitGithubInstallationRequest{})
	return err
}
