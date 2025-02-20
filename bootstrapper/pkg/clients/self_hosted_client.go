package clients

import (
	"context"
	"time"

	selfhosted "github.com/semaphoreio/semaphore/bootstrapper/pkg/protos/self_hosted"
	log "github.com/sirupsen/logrus"
	"google.golang.org/grpc"
)

type SelfHostedClient struct {
	client selfhosted.SelfHostedAgentsClient
}

func NewSelfHostedClient(conn *grpc.ClientConn) *SelfHostedClient {
	return &SelfHostedClient{
		client: selfhosted.NewSelfHostedAgentsClient(conn),
	}
}

func (c *SelfHostedClient) Create(orgId, requesterId, name string) (*selfhosted.CreateResponse, error) {
	ctx, cancel := context.WithTimeout(context.Background(), time.Second*10)
	defer cancel()

	req := &selfhosted.CreateRequest{
		OrganizationId: orgId,
		Name:           name,
		RequesterId:    requesterId,
		AgentNameSettings: &selfhosted.AgentNameSettings{
			AssignmentOrigin: selfhosted.AgentNameSettings_ASSIGNMENT_ORIGIN_AGENT,
			ReleaseAfter:     0,
		},
	}

	resp, err := c.client.Create(ctx, req)
	if err != nil {
		log.Errorf("Failed to create self-hosted agent: %v", err)
		return nil, err
	}

	log.Infof("Successfully created self-hosted agent")
	return resp, nil
}
