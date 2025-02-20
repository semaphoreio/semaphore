package service

import (
	"context"
	"time"

	"github.com/google/uuid"

	"github.com/semaphoreio/semaphore/velocity/pkg/config"
	"github.com/semaphoreio/semaphore/velocity/pkg/protos/projecthub"
	"google.golang.org/grpc"
)

type ProjectHubGrpcClient struct {
	conn *grpc.ClientConn
}

type ProjectHubClient interface {
	Describe(withRequest *ProjectHubDescribeOptions) (*projecthub.DescribeResponse, error)
	List(withRequest *ProjectHubListOptions) (*projecthub.ListResponse, error)
	ListAll(orgId string) ([]*Project, error)
}

func NewProjectHubService(conn *grpc.ClientConn) *ProjectHubGrpcClient {
	return &ProjectHubGrpcClient{
		conn: conn,
	}
}

type ProjectHubDescribeManyOptions struct {
	ProjectIDs []string
}

type ProjectHubDescribeOptions struct {
	ProjectID string
}

type ProjectHubListOptions struct {
	OrgID    string
	Page     int32
	PageSize int32
}

func (c *ProjectHubGrpcClient) Describe(o *ProjectHubDescribeOptions) (*projecthub.DescribeResponse, error) {
	client := projecthub.NewProjectServiceClient(c.conn)
	request := projecthub.DescribeRequest{
		Id:       o.ProjectID,
		Detailed: false,
		Metadata: &projecthub.RequestMeta{
			OrgId: "",
		}}

	tCtx, cancel := context.WithTimeout(context.Background(), config.GrpcCallTimeout()*time.Second)
	defer cancel()
	return client.Describe(tCtx, &request)
}

func (c *ProjectHubGrpcClient) DescribeMany(o *ProjectHubDescribeManyOptions) ([]*projecthub.Project, error) {

	client := projecthub.NewProjectServiceClient(c.conn)
	request := projecthub.DescribeManyRequest{
		Ids: o.ProjectIDs,
		Metadata: &projecthub.RequestMeta{
			OrgId: "",
		}}

	tCtx, cancel := context.WithTimeout(context.Background(), config.GrpcCallTimeout()*time.Second)
	defer cancel()
	response, err := client.DescribeMany(tCtx, &request)
	if err != nil {
		return nil, err
	}

	return response.Projects, nil
}

func (c *ProjectHubGrpcClient) List(o *ProjectHubListOptions) (*projecthub.ListResponse, error) {
	client := projecthub.NewProjectServiceClient(c.conn)

	if o.PageSize == 0 {
		o.PageSize = 500
	}

	request := projecthub.ListRequest{
		Metadata: &projecthub.RequestMeta{
			OrgId: o.OrgID,
		},
		Pagination: &projecthub.PaginationRequest{
			Page:     o.Page,
			PageSize: o.PageSize,
		},
	}

	tCtx, cancel := context.WithTimeout(context.Background(), config.GrpcCallTimeout()*time.Second)
	defer cancel()
	return client.List(tCtx, &request)
}

func (c *ProjectHubGrpcClient) ListAll(orgId string) ([]*Project, error) {
	var projects []*projecthub.Project
	page := int32(0)
	pageSize := int32(200)

	for {
		resp, err := c.List(&ProjectHubListOptions{
			OrgID:    orgId,
			Page:     page,
			PageSize: pageSize,
		})

		if err != nil {
			return nil, err
		}

		projects = append(projects, resp.Projects...)

		if resp.Pagination.TotalPages == page {
			break
		}

		page++
	}

	var result []*Project

	for _, p := range projects {
		result = append(result, parseProject(p))
	}

	return result, nil
}

type Project struct {
	Id             uuid.UUID
	Name           string
	DefaultBranch  string
	OrganizationId uuid.UUID
}

func parseProject(p *projecthub.Project) *Project {
	id := uuid.Nil
	organizationId := uuid.Nil
	name := ""
	defaultBranch := ""

	if p.Metadata != nil {
		name = p.Metadata.Name
		if v, err := uuid.Parse(p.Metadata.Id); err == nil {
			id = v
		}

		if v, err := uuid.Parse(p.Metadata.OrgId); err == nil {
			organizationId = v
		}
	}

	if p.Spec != nil && p.Spec.Repository != nil {
		defaultBranch = p.Spec.Repository.DefaultBranch
	}

	return &Project{
		Id:             id,
		Name:           name,
		DefaultBranch:  defaultBranch,
		OrganizationId: organizationId,
	}
}
