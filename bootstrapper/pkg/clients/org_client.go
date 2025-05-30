package clients

import (
	"context"
	"errors"
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

// Describe fetches organization details by username or ID
func (c *OrgClient) Describe(orgID, orgUsername string) (*organization.Organization, error) {
	ctx, cancel := context.WithTimeout(context.Background(), time.Second*10)
	defer cancel()

	req := &organization.DescribeRequest{
		OrgId:        orgID,
		OrgUsername:  orgUsername,
		IncludeQuotas: false,
	}

	resp, err := c.client.Describe(ctx, req)
	if err != nil {
		log.Debugf("Organization lookup returned an error: %v", err)
		return nil, err
	}

	// Check if the response status indicates success
	if resp.GetStatus() == nil {
		log.Debugf("Organization lookup returned nil status")
		return nil, errors.New("organization not found or error in response status")
	}

	org := resp.GetOrganization()
	if org == nil {
		log.Debugf("Organization lookup returned nil organization")
		return nil, errors.New("organization not found")
	}

	log.Debugf("Found organization: username=%s, orgId=%s", org.GetOrgUsername(), org.GetOrgId())
	return org, nil
}
