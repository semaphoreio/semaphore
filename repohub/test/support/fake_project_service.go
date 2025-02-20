package testsupport

import (
	"context"
	"fmt"

	uuid "github.com/satori/go.uuid"
	ia "github.com/semaphoreio/semaphore/repohub/pkg/internal_api/projecthub"
)

type FakeProjectService struct {
	ia.UnimplementedProjectServiceServer
}

func (*FakeProjectService) List(ctx context.Context, in *ia.ListRequest) (*ia.ListResponse, error) {
	return nil, fmt.Errorf("Not implemented")
}

func (*FakeProjectService) Describe(ctx context.Context, in *ia.DescribeRequest) (*ia.DescribeResponse, error) {
	return &ia.DescribeResponse{
		Metadata: &ia.ResponseMeta{
			Status: &ia.ResponseMeta_Status{
				Code: ia.ResponseMeta_OK,
			},
		},
		Project: &ia.Project{
			Metadata: &ia.Project_Metadata{
				OwnerId: uuid.NewV4().String(),
			},
		},
	}, nil
}
