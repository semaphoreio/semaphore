package clients

import (
	"context"
	"time"

	"github.com/semaphoreio/semaphore/bootstrapper/pkg/protos/organization"
	log "github.com/sirupsen/logrus"
	"google.golang.org/grpc"
)

type OrgClient struct {
	client organization.OrganizationServiceClient
}

func NewOrgClient(conn *grpc.ClientConn) *OrgClient {
	return &OrgClient{
		client: organization.NewOrganizationServiceClient(conn),
	}
}

func (c *OrgClient) Create(creatorID, organizationName, organizationUsername string) (*organization.Organization, error) {
	ctx, cancel := context.WithTimeout(context.Background(), time.Second*10)
	defer cancel()

	req := &organization.CreateRequest{
		CreatorId:            creatorID,
		OrganizationName:     organizationName,
		OrganizationUsername: organizationUsername,
	}

	resp, err := c.client.Create(ctx, req)
	if err != nil {
		log.Errorf("Failed to create organization: %v", err)
		return nil, err
	}

	org := resp.GetOrganization()
	log.Infof("Created organization: username=%s, orgId=%s", org.GetOrgUsername(), org.GetOrgId())
	return org, nil
}
