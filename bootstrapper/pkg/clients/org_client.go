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
		OrgId:         orgID,
		OrgUsername:   orgUsername,
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

// ListOrganizations returns a list of all organizations.
// If pageSize is 0, a default page size will be used.
// If pageToken is empty, it will fetch the first page.
func (c *OrgClient) ListOrganizations(pageSize int32, pageToken string) ([]*organization.Organization, string, error) {
	ctx, cancel := context.WithTimeout(context.Background(), time.Second*10)
	defer cancel()

	req := &organization.ListRequest{
		PageSize:  pageSize,
		PageToken: pageToken,
	}

	resp, err := c.client.List(ctx, req)
	if err != nil {
		log.Errorf("Failed to list organizations: %v", err)
		return nil, "", err
	}

	log.Debugf("Retrieved %d organizations", len(resp.GetOrganizations()))
	return resp.GetOrganizations(), resp.GetNextPageToken(), nil
}

func (c *OrgClient) ListAllOrganizations() ([]*organization.Organization, error) {
	organizations := []*organization.Organization{}
	pageSize := int32(100)
	pageToken := ""
	for {
		orgs, nextToken, err := c.ListOrganizations(pageSize, pageToken)
		if err != nil {
			return nil, err
		}

		organizations = append(organizations, orgs...)
		if nextToken == "" {
			break
		}
		pageToken = nextToken
	}

	return organizations, nil
}
